---
name: adversarial-review
description: Use during /opus-harness:cycle Phase 2 (plan self-review) and Phase 4 (per-slice verify + 3-dimension scoring panel). Defines reviewer dispatch, scoring, gates, scorecard format.
---

# Adversarial Review

通則：reviewer 一律是 **fresh-context subagent**（Agent tool），輸入只給工件（spec／計畫／diff），**絕不給實作過程對話**——防自欺污染。機械性檢查用便宜模型，判斷性審查才用主模型。

## A. 計畫自我審查（Phase 2，人類看到結論前）

- 持久型計畫 → 2 個 reviewer 並行；臨時型 → 只跑 reviewer 1（model: sonnet）。
- **Reviewer 1「完整性」（model: sonnet）**——prompt 給：spec 全文＋計畫全文。要求逐項勾稽並回 JSON：
  `{"pass": bool, "findings": [{"type": "uncovered-goal|oversized-slice|vague-acceptance|dependency-error", "detail": "...", "slice": "..."}]}`
  檢查：① spec 量化目標每條都有切片覆蓋 ② 每片 ≤ 一個行為（約 ≤ 3 檔案）③ 每片驗收是具體指令＋預期結果（不是「應該能動」）④ 片間依賴順序可執行。
- **Reviewer 2「唱反調」（model: 繼承主模型）**——prompt 給：spec＋計畫。任務：「找出這個計畫會失敗的方式」——遺漏的風險、隱含假設、會互相衝突的切片、低估的複雜度。回 JSON 同上（type 自由）。
- findings → 直接修訂計畫 → 重審，**最多 2 輪**；仍不過 → 升級人類（升級條件 #2）。

## B. 每片 verifier（Phase 3 每片收尾）

- 1 個 subagent（model: sonnet），輸入：該片驗收標準＋`git diff <片起點>..HEAD`（片起點 = 上一個 `last_green_commit`；首片 = state 的 `start_commit`）＋驗收指令的實際輸出。
- 任務：「驗收標準是否真的被滿足？輸出是否真的證明了主張？」回 `{"pass": bool, "reason": "..."}`。
- fail → 該片不算完成，紅計數照常累加（棘輪管轄）。

## C. 三面向評分小組（Phase 4，feature 完成時）

每個面向一個 reviewer、並行（model: 繼承主模型）；面向清單取自 `config.review.dimensions`（預設三項，ablation 時可減）。共同輸入：spec＋完整 diff（`state.start_commit`..HEAD）＋各自面向指引。各回：

```json
{
  "dimension": "performance|maintainability-readability|security",
  "score": 0,
  "specCompliant": true,
  "findings": [{ "severity": "blocker|major|minor", "file": "...", "detail": "..." }]
}
```

- **效能**：演算法複雜度、N+1、不必要重算/重渲染、記憶體與 bundle 熱點。`config.skillDispatch` 有對應條目（如 react）→ 先載入該 skill 再審。
- **可維護性與可讀性**：簡化機會、慣例一致、命名、最小變更原則。有安裝 code-review / simplify skill → 作為本面向工具。
- **資安**：輸入驗證、注入、秘密洩漏、權限邊界。有 security-review skill → 優先使用。
- severity 定義：blocker = 不修就會造成事故或顯著退化；major = 應修但不擋合併安全；minor = 建議。

**判定**：無 blocker 且每面向 score ≥ `config.review.threshold`（預設 7）→ 放行。否則修正後重審，**最多 2 輪**；仍不過 → 升級人類。

**scorecard**：每次小組結束，追加一筆到 `.claude/harness/scorecard.json`（JSON 陣列檔；不存在則建立 `[]` 再追加）：

```json
{ "ts": "<ISO8601>", "cycle_id": "...", "scores": { "performance": 8, "maintainability-readability": 7, "security": 9 }, "blockers": 0, "majors": 1, "rounds": 1, "findings": [{ "severity": "major", "file": "...", "detail": "..." }] }
```

（`findings` = 三位 reviewer 的發現合併；retro 的回顧來源之一，不存就丟了。）

## D. 紅隊（選配 --redteam）

1 個 subagent，輸入 spec＋diff，唯一任務：「寫出一個會讓這份實作 fail 的測試」。寫得出來且合理 → 該測試進測試集、回 Phase 3 修；寫不出來 → 記錄嘗試方向。
