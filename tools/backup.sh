#!/usr/bin/env bash
# 把整個資料庫備份到 backups/（只讀，不會改到任何資料）。
#   用法：bash tools/backup.sh <你的名字>          正式站
#         bash tools/backup.sh <你的名字> test     測試站
# 資料庫只讓成員讀，所以要用自己的帳號登入；密碼會在執行時詢問（不顯示、不留紀錄）。
# 備份檔是大家的資料，backups/ 已列在 .gitignore，不要手動加進 git、不要傳給別人。
set -euo pipefail
cd "$(dirname "$0")/.."

name="${1:-}"
[ -n "$name" ] || { echo "用法：bash tools/backup.sh <你的名字> [test]"; exit 1; }
src=index.html; [ "${2:-}" = test ] && src=test/index.html
key=$(grep -o 'apiKey: "[^"]*"' "$src" | head -1 | cut -d'"' -f2)
db=$(grep -o 'databaseURL: "[^"]*"' "$src" | head -1 | cut -d'"' -f2)

# 名單與帳號版本是公開的，用來從名字推出登入用的 email（跟網頁同一套）
email=$(NAME="$name" PL="$(curl -sf "$db/data/people-list.json")" AV="$(curl -sf "$db/authver.json")" python -I -c '
import json, os
people = json.loads(json.loads(os.environ["PL"]))
av = json.loads(os.environ["AV"] or "null") or {}
hit = [p for p in people if p["name"] == os.environ["NAME"]]
print(hit[0]["id"] + "." + av.get(hit[0]["id"], "0") + "@weekly-sport.invalid" if hit else "")
')
[ -n "$email" ] || { echo "名單裡沒有「$name」"; exit 1; }

read -r -s -p "「$name」的密碼：" pw; echo
token=$(PW="$pw" EMAIL="$email" python -I -c '
import json, os
print(json.dumps({"email": os.environ["EMAIL"], "password": os.environ["PW"], "returnSecureToken": True}))
' | curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$key" \
    -H 'Content-Type: application/json' --data-binary @- \
  | grep -o '"idToken": *"[^"]*"' | cut -d'"' -f4 || true)
unset pw
[ -n "$token" ] || { echo "登入失敗（密碼不對？），沒有備份"; exit 1; }

mkdir -p backups
out="backups/$(basename "$db" .firebasedatabase.app)-$(date +%Y%m%d-%H%M%S).json"
# 規則不開放讀整個根節點，四個節點分開讀再合成一個檔
for n in data claims members authver; do
  curl -sf "$db/$n.json?auth=$token" -o "$out.$n" || { rm -f "$out".*; echo "讀不到資料（帳號還沒綁定？），沒有備份"; exit 1; }
done
# 運動日曆的照片：規則還沒貼的專案讀不到，讀不到就跳過，不讓整份備份失敗
for n in photo-day photo-full; do
  curl -sf "$db/$n.json?auth=$token" -o "$out.$n" || { rm -f "$out.$n"; echo "（$n 讀不到，跳過）"; }
done
OUT="$out" python -I -c '
import json, os
o = os.environ["OUT"]
names = ["data", "claims", "members", "authver"] + [n for n in ["photo-day", "photo-full"] if os.path.exists(o + "." + n)]
json.dump({n: json.load(open(o + "." + n, encoding="utf-8")) for n in names},
          open(o, "w", encoding="utf-8"), ensure_ascii=False)
'
rm -f "$out".*

# 檢查真的拿到東西：要有成員名單
if ! grep -q 'people-list' "$out"; then
  echo "備份內容不完整（沒有成員名單），已刪除：$out"; rm -f "$out"; exit 1
fi
echo "已備份：$out（$(wc -c < "$out") bytes）"
