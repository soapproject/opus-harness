---
description: 啟動品質循環：量化 spec → 計畫(自我審查) → TDD → 三面向投票 → retro
argument-hint: <任務描述> | pause | resume
---

# /opus-harness:cycle

引數：`$ARGUMENTS`

## 子指令

- `pause`：state.json `suspended: true`，回報「hooks 已放行（infra 修復模式）」，結束。
- `resume`：`suspended: false`，回報恢復，結束。
- 其餘 = 任務描述，走主流程。

## 前置檢查（依序，任一不過就處理完才繼續）

1. `.claude/harness/config.json` 存在？否 → 先完整執行 /opus-harness:calibrate 的步驟。
2. `git rev-parse --is-inside-work-tree` 成功？否 → 提議 `git init`（棘輪依賴 git）；使用者拒絕 → 明說 cycle 無法啟動並停止。
3. `config.commands.test` 存在？否 → 回 calibrate 補測試框架（TDD 硬前提）。
4. `plans/` 有未完成的 persistent 計畫（檔內仍有 `- [ ]`）？→ 問使用者：恢復它（state 指回該計畫、phase=executing）或歸檔（搬 `plans/done/`）後開新的。不默默開新的。

## 啟動

寫 `.claude/harness/state.json`：

```json
{
  "cycle_id": "<YYYYMMDD-HHmm>-<topic 短 slug>",
  "phase": "brainstorm",
  "plan_path": "",
  "plan_type": "",
  "active_slice": "",
  "red_count": 0,
  "last_green_commit": "",
  "suspended": false,
  "stop_block_count": 0,
  "started_at": "<ISO8601>",
  "updated_at": "<ISO8601>"
}
```

然後 Invoke Skill `opus-harness:harness-cycle`，帶上任務描述，照其 Phase 表走到 done。
