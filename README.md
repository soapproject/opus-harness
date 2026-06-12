# opus-harness

讓較弱模型（Opus 4.8）維持工作品質的鷹架：模型越弱、鷹架越硬。

## 安裝

從 GitHub：

1. `/plugin marketplace add soapproject/opus-harness`
2. `/plugin install opus-harness@opus-harness-local`
3. 重啟 Claude Code session。

或從本地 clone：`/plugin marketplace add <path-to-repo>` 後同上。
4. 註：`marketplace.json` 的 `source: "./"` 是相對 marketplace 根（= repo 根）解析，本 repo 兼作自身的 marketplace。

## 指令

| 指令 | 用途 |
|---|---|
| `/opus-harness:calibrate` | 每專案一次：偵測工具鏈 → `.claude/harness/config.json` |
| `/opus-harness:cycle <任務>` | 主流程：量化 spec → 計畫(自我審查) → TDD → 三面向投票 → retro |
| `/opus-harness:retro` | 經驗蒸餾（兩次門檻 → CLAUDE.md ## Lessons） |
| `/opus-harness:bench` | harness 回歸測試（golden set） |

## 迭代協定（spec §10 摘要）

- 每條硬約束登記於 `constraints.md`（防範模式／證據／鬆綁階梯／挑戰條件）。
- hooks 觸發寫入專案 `telemetry.jsonl`；高摩擦約束優先檢討。
- 模型升級：bench 對比 → 逐一 ablation（手動關約束重跑）→ 沿鬆綁階梯放鬆 → scorecard 監測。
- lesson 級改進自動（/retro 兩次門檻）；機制級走分支 + bench A/B + **人類核准合併（不可配置）**。
