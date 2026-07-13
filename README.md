# 每週運動排程系統

給 LINE 群組使用的每週運動時間協調小工具。單一 `index.html` 檔案，前端使用原生 JavaScript，資料儲存在 Firebase Realtime Database，並部署於 GitHub Pages。

🔗 線上使用：https://14sail.github.io/weekly-sport/

## 功能

- **成員回報時間**：每位成員可針對「本週＋未來3週」每一週的週一到週五，勾選「有空／不確定／沒空」，並可留言給老師（例如想打什麼球、身體狀況等）。
- **老師統計總覽**：彙整當週所有成員的回覆狀況，並在老師本人也回報「有空」的日子中，自動標記出「學生有空人數最多」的建議日期。
- **公告產生**：老師選擇日期、時間、運動項目、附加提醒後，一鍵產生公告文字，可直接複製貼到 LINE 群組。
- **人員管理**：管理入口可新增／刪除成員、指定或取消老師身份、重設成員密碼。
- **簡易帳號機制**：每位成員第一次使用時自行設定顯示名稱與密碼，之後用密碼登入；可自行修改名字或密碼。

## 技術架構

- 純前端單檔（`index.html`），無建置流程，直接部署即可使用。
- 資料庫：Firebase Realtime Database（透過 CDN 載入 Firebase SDK，見檔案開頭 `firebaseConfig`）。
- 所有資料存放在單一 `data/` 節點下，依 key 前綴區分：
  - `people-list`：人員清單 `[{id, name, isTeacher, password}]`
  - `resp:<週一日期>:<人員id>`：某人某週的回報 `{statuses: {日期: 'free'|'maybe'|'busy'}, note}`
  - `announce:<週一日期>`：該週產生的公告內容
- 每次載入頁面會自動清除已經過期（不在「本週＋未來3週」範圍內）的回報與公告資料。

## 部署方式（GitHub Pages）

本專案直接以 `index.html` 作為靜態網頁部署：

1. Push 到 GitHub 的 `main` 分支。
2. GitHub 專案設定（Settings → Pages）中，Source 設定為 `main` 分支、根目錄 `/`。
3. 幾分鐘後即可透過 `https://<帳號>.github.io/<repo>/` 存取。

## Firebase 設定

若要換成自己的 Firebase 專案，修改 `index.html` 開頭 `<script type="module">` 區塊中的 `firebaseConfig`（可在 Firebase Console → 專案設定 → 一般 取得），並確認 Realtime Database 的安全性規則允許讀寫。

## 安全性注意事項

這是為熟人小群組（LINE 群組）設計的輕量工具，**不適合存放敏感資料**。在「單一 HTML 檔案、無後端、免付費方案」的限制下，目前採用以下防護，並誠實列出其極限：

- **資料庫存取**：頁面載入時會自動用 Firebase 匿名登入（`signInAnonymously`），搭配 Realtime Database 規則要求 `auth != null`（見下方「啟用資料庫保護」），可以擋掉「只靠 `apiKey` 直接打 REST API」的隨意存取／掃描。但無法擋住願意讀懂前端程式碼、模仿相同登入流程的針對性攻擊者——要做到每人只能改自己的資料，需要更完整的身份綁定與規則設計，目前沒有做。
- **管理密碼**：原始碼中只存 SHA-256 雜湊值（`ADMIN_PASSWORD_HASH`），不是明碼，一般檢視原始碼看不到密碼本身；但因為沒有後端，比對邏輯仍在瀏覽器端執行，理論上仍可能被離線暴力破解，且**舊密碼 `sport2026` 已經存在 git 歷史中，等同永久外流**，請務必更換成新密碼（見下方「更換管理密碼」）。
- **成員密碼**：以明碼存在資料庫內（不在原始碼、不在 git 歷史），僅用於避免誤觸修改他人回覆，並非正式帳號系統。
- **Firebase 設定（`firebaseConfig`）**：`apiKey` 等值本來就是前端可見的公開識別資訊，無法被「藏起來」，真正的防護仰賴上面的資料庫規則設定。

### 啟用資料庫保護（一次性設定）

1. Firebase Console → Authentication → Sign-in method → 啟用「匿名」登入（免費，不需信用卡）。
2. 確認網站部署新版程式碼後仍正常運作（能選人、儲存回覆）。
3. Firebase Console → Realtime Database → Rules，貼上並發布：
   ```json
   {
     "rules": {
       "data": {
         ".read": "auth != null",
         ".write": "auth != null"
       }
     }
   }
   ```

### 更換管理密碼

1. 開啟瀏覽器 devtools console，執行（把 `新密碼` 換成你要設定的密碼）：
   ```js
   crypto.subtle.digest('SHA-256', new TextEncoder().encode('新密碼')).then(b=>console.log([...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('')))
   ```
2. 把印出的 64 碼十六進位字串，貼到 `index.html` 中的 `ADMIN_PASSWORD_HASH` 常數，取代原本的值。
3. Commit、push 部署即可生效；密碼明碼全程不需要寫進任何檔案。

## 使用方式

1. 開啟網站，選擇自己的名字。
2. 第一次使用需設定密碼；之後每次登入輸入密碼即可。
3. 成員：勾選每天的空閒狀態並儲存。
4. 老師：切換到「老師管理視角」查看統計、產生公告並複製貼到 LINE 群組。
5. 需要新增/刪除成員或指定老師，請由首頁「管理入口」輸入管理密碼進入。
