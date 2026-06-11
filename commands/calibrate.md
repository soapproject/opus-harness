---
description: 校準本專案：偵測工具鏈，產出 .claude/harness/config.json 與目錄結構
---

# /opus-harness:calibrate

對當前專案執行校準。calibrate 是互動指令（cycle 啟動前的設定階段），可以向使用者確認。

## 步驟

1. **偵測索引工具**：嘗試呼叫 `codegraph_status`（ToolSearch 載入）。有索引 → 用 `codegraph_files`/`codegraph_explore` 掃出語言與框架；無 → 步驟 2 檔案探測。
2. **檔案探測**（fallback）：Glob 找 `package.json`、`pyproject.toml`、`cargo.toml`、`go.mod`、`*.csproj`。從內容判讀 stack 與既有 scripts（test/lint/build…）。
3. **組出五個指令**：`test`、`testQuick`（受影響範圍的快跑版，如 `vitest related --run`、`pytest -x --lf`；無快跑法就同 `test`）、`lint`、`typecheck`、`build`。每個指令先實際跑一次驗證可執行（容許測試紅，但指令本身要能跑）。
4. **無測試框架 → 硬要求**：向使用者提議安裝該 stack 的標準測試框架並完成最小設定（一個可跑的空測試）。使用者拒絕 → 明說「/cycle 將無法啟動（TDD 硬前提）」並停止。
5. **寫設定**：建立目錄 `.claude/harness/{specs,plans,plans/done,tmp}`；寫 `.claude/harness/config.json`，欄位見 plugin 的 `templates/config.schema.json`；**寫完整 config（所有選用欄位都帶預設值——schema 的 default 不會自動生效，這是 schema 開頭 description 明定的消費者契約）**。PS 5.1 無 `Test-Json`，改以 `ConvertFrom-Json` 解析＋檢查必填欄位 `commands.test` 非空驗證。`skillDispatch` 依偵測結果填（react → vercel-react-best-practices、vercel-composition-patterns；ui → web-design-guidelines；security → security-review；查無已安裝 skill 就不填該鍵）。
6. **gitignore**：專案 `.gitignore` 追加一行 `.claude/harness/tmp/`（已有則略）。
7. **CLAUDE.md 指標**：專案 CLAUDE.md 確保存在一行（不複製指令內容，控制 context 肥胖）：
   `> opus-harness 已校準：驗證指令見 .claude/harness/config.json`
8. **回報結論卡**：stack、五指令、skillDispatch、缺了什麼。一張表，不貼檔案全文。

## config.json 範例（完整形）

```json
{
  "stack": ["nextjs", "typescript"],
  "commands": {
    "test": "npm test",
    "testQuick": "npx vitest related --run",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "build": "npm run build"
  },
  "skillDispatch": {
    "react": ["vercel-react-best-practices", "vercel-composition-patterns"],
    "ui": ["web-design-guidelines"],
    "security": ["security-review"]
  },
  "indexTools": { "codegraph": true },
  "voting": { "panelSize": 3, "ratchetLimit": 2 },
  "review": { "dimensions": ["performance", "maintainability-readability", "security"], "threshold": 7 },
  "planApproval": "notify"
}
```
