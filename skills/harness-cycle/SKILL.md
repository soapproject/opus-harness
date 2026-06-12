---
name: harness-cycle
description: Orchestrates /opus-harness:cycle phases - state machine, delegation table to superpowers skills, injections, autonomy rules, escalation whitelist, conclusion cards.
---

# Harness Cycle 編排

你是流程編排者。每個 phase：更新 state → 委派/執行 → 產出檢查 → 下一 phase。**Phase 2 起全自動**，只有升級白名單能暫停。

## state.json 維護（你負責寫，hooks 負責讀）

位置 `.claude/harness/state.json`。phase 轉換時更新 `phase` 與 `updated_at`。執行期欄位：
- 每次跑測試**紅** → `red_count` +1；**綠且 commit** → `last_green_commit` = 新 commit hash、`red_count` = 0、勾掉計畫 checkbox。
- 換片 → `active_slice` = 片名。
- `/opus-harness:cycle pause` → `suspended: true`（hooks 放行）；`resume` → false。
- 棘輪鎖定後的解鎖路徑（hook 訊息也會這樣指示）：git stash → git reset --hard 回綠點 → 重切計畫 → red_count 歸零。
- `start_commit`：cycle 啟動時由 /cycle 寫入（HEAD hash），審查與打包的 diff 起點，**不得修改**。
- 紀律紅線：`suspended` 只能經 pause/resume 子指令變更；`phase: "done"` 只能在 wrapup 全套指令綠之後設定。繞過這兩條＝遙測與 retro 的稽核對象。

## Phase 表

| phase | 委派 | 注入 | 產出檢查 |
|---|---|---|---|
| brainstorm | superpowers:brainstorming | opus-harness:quantified-spec | spec 五標題齊全，存 specs/ |
| plan | superpowers:writing-plans | 切片規則＋計畫審查（下述） | 結論卡已回報 |
| executing | superpowers:subagent-driven-development（>3 片）或 superpowers:executing-plans（≤3 片） | TDD＋每片 verifier＋棘輪紀律 | 全片勾完、全綠 |
| review | opus-harness:adversarial-review §C | --redteam 時加 §D | 無 blocker、面向達標、scorecard 已寫 |
| wrapup | superpowers:verification-before-completion | config 全套指令 | /opus-harness:retro 已跑 |

superpowers 未安裝 → 每 phase 改用下方「最小 checklist」，流程不中斷。

## Phase 1 brainstorm（人類密集參與，唯一的共創階段）

照 brainstorming skill 互動。探索一律 codegraph 優先。產出按 quantified-spec 模板，五區塊缺一不可。
最小 checklist（降級用）：理解意圖 → 2-3 方案比較 → 分節確認設計 → 按模板寫 spec。

## Phase 2 plan（人類只收結論）

1. 規模分流：預估 ≤ 2 片且小改 → ephemeral（`.claude/harness/tmp/plan-<cycle_id>.md`，wrapup 時刪）；否則 persistent（`.claude/harness/plans/YYYY-MM-DD-<topic>.md`，wrapup 時搬 `.claude/harness/plans/done/`）。
2. 委派 writing-plans。硬規則：每片 ≤ 一個行為（約 ≤ 3 檔案）；每片驗收 = 具體指令＋預期結果。每片必須內嵌對應的 spec 測試案例（ID＋Given/When/Then 全文）——執行期 subagent 只拿到片文，沒內嵌＝拿不到。
3. 計畫含 `## Decisions` 空區塊（decide-and-log 落點）。
4. 跑 adversarial-review §A（persistent 2 人／ephemeral 1 人，≤ 2 輪自動修訂）。
5. **結論卡**回報（不貼計畫全文）：

```
📋 計畫結論｜<topic>
目標：<一句話>｜切片：N 片｜類型：persistent/ephemeral
關鍵風險：<1-3 條>
計畫審查：reviewer 結論與修訂摘要（第幾輪過）
檔案：<計畫路徑>
```

6. `config.planApproval`："notify" → 回報後直接續行；"always-ask" → AskUserQuestion 等核准。

最小 checklist（降級用）：切片表（片名/檔案/驗收指令/預期）→ §A 審查 → 結論卡。

## Phase 3 executing（TDD 鐵律）

每片循環：寫失敗測試（從 spec 測試案例清單取）→ 跑測試確認紅 → 最小實作 → 跑測試確認綠 → 重構 → commit → 每片 verifier（adversarial-review §B）→ 勾 checkbox、更新 state。
- 棘輪由 hook 強制：紅 2 次鎖編輯，唯一出路 stash → reset --hard 回綠點 → 重切。這不是建議，是硬閘。
- subagent-driven 模式：每片派 fresh subagent，輸入 = 計畫該片全文＋spec 檔路徑（不依賴對話記憶）。**subagent 的 prompt 必須包含 state 維護契約**：測試紅 → `state.json` 的 `red_count` +1；綠且 commit → `last_green_commit` 更新、`red_count` 歸零——否則棘輪在此模式下形同虛設。
最小 checklist（降級用）：嚴格紅綠重構循環＋每片 commit，自行維護 state 欄位。

## Phase 4 review

adversarial-review §C（必要時 §D）。修正循環中的程式碼改動回到 Phase 3 紀律（測試先行），**期間把 `phase` 設回 `"executing"`（兩個 hook 重新武裝），修完設回 `"review"` 重審**。

## Phase 5 wrapup

config 全套（test/lint/typecheck/build）逐一跑綠 → verification-before-completion 清單 → 呼叫 /opus-harness:retro → 計畫歸檔/刪除 → `phase: "done"` → 最終回報（結論先行：達成的量化目標逐項打勾、scorecard 分數、Decisions 攤開、檔案連結）。

## 自動化規則（Phase 2 起生效）

- **禁止中途提問**。含糊處 → **decide-and-log**：做合理決定，寫進計畫 `## Decisions`（決定／理由／影響範圍），wrapup 攤開。
- **升級提問一律用 AskUserQuestion 工具**（工具呼叫不會結束回合，因此不會觸發 stop-gate 重跑測試）；不得用「結束回合等回覆」的方式升級——phase=executing 時那會被 stop-gate 擋下。
- **結論先行**：每次回報 = 結論＋關鍵證據摘要＋檔案連結。
- **升級白名單（僅此六種可暫停問人）**：① 資安 blocker ② 審查/投票兩輪仍不過 ③ 棘輪同片第二次觸發（重切後仍失敗）④ 超出 spec 邊界的 scope 變更 ⑤ 缺工具/憑證無法自補 ⑥ 不可逆/破壞性操作。

## 模型分配

| 用途 | model |
|---|---|
| 每片 verifier、計畫完整性 reviewer | sonnet |
| 唱反調、三面向小組、紅隊 | 繼承主模型 |
| 機械文字處理（log 摘要等） | haiku |
