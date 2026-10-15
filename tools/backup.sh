#!/usr/bin/env bash
# 把正式站整個資料庫備份到 backups/（只讀，不會改到任何資料）。
#   用法：bash tools/backup.sh          正式站
#         bash tools/backup.sh test     測試站
# 備份檔裡有大家的密碼明碼，backups/ 已列在 .gitignore，不要手動加進 git、不要傳給別人。
set -euo pipefail
cd "$(dirname "$0")/.."

src=index.html; [ "${1:-}" = test ] && src=test/index.html
key=$(grep -o 'apiKey: "[^"]*"' "$src" | head -1 | cut -d'"' -f2)
db=$(grep -o 'databaseURL: "[^"]*"' "$src" | head -1 | cut -d'"' -f2)

# 資料庫規則要求登入，跟網頁一樣用匿名登入拿通行證
token=$(curl -sf -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$key" \
  -H 'Content-Type: application/json' -d '{"returnSecureToken":true}' \
  | grep -o '"idToken": *"[^"]*"' | cut -d'"' -f4)
[ -n "$token" ] || { echo "登入失敗，沒有備份"; exit 1; }

mkdir -p backups
out="backups/$(basename "$db" .firebasedatabase.app)-$(date +%Y%m%d-%H%M%S).json"
curl -sf "$db/data.json?auth=$token" -o "$out"

# 檢查真的拿到東西：要有成員名單，而且不能是空的
if ! grep -q '"people-list"' "$out"; then
  echo "備份內容不完整（沒有成員名單），已刪除：$out"; rm -f "$out"; exit 1
fi
echo "已備份：$out（$(wc -c < "$out") bytes）"
