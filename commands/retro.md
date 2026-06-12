---
description: 經驗蒸餾：回顧本次 cycle，候選 lessons 兩次門檻晉升 CLAUDE.md，並提議打包 benchmark case
---

# /opus-harness:retro

載入 Skill `opus-harness:lesson-distill` 後執行：

## 1. 回顧來源（逐一檢視）

- 本次 cycle 哪裡卡住（棘輪/stop-gate 觸發：讀 `.claude/harness/telemetry.jsonl` 本 cycle 區段）
- reviewer 抓到什麼（`.claude/harness/scorecard.json` 最新一筆的 findings 與 blockers/majors、計畫審查的修訂）
- 使用者糾正了什麼（對話中的指正）
- scorecard 趨勢：近 5 筆中持續 < threshold+1 的面向 → 候選 lesson（threshold 取自 `config.review.threshold`）。任一來源檔不存在 → 回報「無資料」並跳過，不中斷。

## 2. 蒸餾

按 lesson-distill 規則：寫候選 → 語意查重 → 兩次門檻晉升（含 @模型標籤、層級路由）→ cap 30 檢查。

## 3. harness 健康節（scorecard.json 筆數為 5 的倍數時執行）

telemetry.jsonl 統計：各約束觸發次數、觸發後結果（block 後最終綠了？fail-open 多不多？harness-edit-allowed 自鬆綁有幾次？）。「常觸發＋常被 pause」的約束 → 回報為摩擦候選（人類決定是否走 spec §10.3 ablation）。

## 4. benchmark case 打包（問一句）

「這個任務存成 benchmark case？」同意 → 在 opus-harness repo（向使用者確認路徑，預設 `<path-to-repo>`）的 `bench/cases/case-NN-<topic>/` 建：
- `spec.md`：複製本次量化 spec
- `rubric.md`：從 templates/rubric.md 複製，填入本 case 特化要點與 baseline 總分
- `baseline/`：`git diff <cycle 起點>..HEAD` 存為 `baseline.diff`＋最終 scorecard 分數存 `scores.json`
- `verify.ps1`：本次 spec「驗證工具與方法」表轉成腳本（跑指令、驗 exit code；參數 `param([string]$Workdir)`，在 $Workdir 下執行）
- `case.json`：`{ "repo": "<專案絕對路徑>", "startCommit": "<state.start_commit>", "prompt": "<原始任務描述>" }`

## 5. 回報

結論卡：新候選 N 條、晉升 N 條（內容列出）、蒸餾/歸檔動作、case 打包結果。
