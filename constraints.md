# 約束登記表（Chesterton's Fence Registry）

規則：無登記的約束不得上線。`挑戰條件` 預設 = 模型升級時跑 ablation（spec §10.3）。
遙測：每次觸發寫入專案 `telemetry.jsonl`，constraint 欄位 = 本表 id。

---
## stop-gate
- 防範：宣稱完成但驗證為紅（弱模型自我驗證誠實度不足）
- 證據：設計假說 2026-06-12（Fable→Opus 能力斷崖分析）
- 摩擦成本：每次 Stop 跑一次 testQuick（秒級～分級）
- 鬆綁階梯：重跑測試 → 改驗 transcript 中的測試證據 → 關閉
- 挑戰條件：模型升級；或遙測顯示連續 30 次觸發皆綠（= 模型已不需要）

## ratchet（red_count ≥ ratchetLimit 鎖編輯）
- 防範：debug 死亡螺旋燒 token、越改越爛
- 證據：設計假說 2026-06-12
- 摩擦成本：誤判時需 /cycle pause（infra 紅非程式碼紅）
- 鬆綁階梯：limit 2 → 3 → 5 → 關閉
- 挑戰條件：模型升級；或遙測顯示觸發後 revert 重切的成功率不優於放任繼續修
- 遙測補充：鎖定中放行 .claude/harness 下編輯時記 harness-edit-allowed 事件（自鬆綁稽核，供 /retro 檢視）
- 已知缺口：matcher 只攔 Edit/Write/MultiEdit/NotebookEdit；Bash 寫檔可繞過（解鎖路徑比繞過便宜，風險評為低；繞過行為列入 retro 稽核）

## review-threshold（三面向各 ≥ 7 且無 blocker）
- 防範：低品質碼過關（效能／可維護可讀／資安）
- 證據：設計假說 2026-06-12；起手值未校準，待 scorecard 數據
- 摩擦成本：每 feature 3 個 Opus reviewer + 可能的修正循環
- 鬆綁階梯：threshold 7 → 6；panel 3 人 → 1 人＋抽查 → 關閉
- 挑戰條件：模型升級；scorecard 連續 10 cycle 全面向 ≥ 8

## plan-review-rounds（計畫自我審查 ≤ 2 輪）
- 防範：計畫品質差直接執行；以及無限修訂循環
- 證據：設計假說 2026-06-12
- 摩擦成本：每計畫 1–2 個 reviewer agents
- 鬆綁階梯：持久型 2 人 → 1 人 → 抽查
- 挑戰條件：模型升級；計畫審查 finding 率持續為 0

## lesson-two-strike（同類問題第 2 次才進 CLAUDE.md）
- 防範：CLAUDE.md context 肥胖（不相關長 context 干擾弱模型）
- 證據：設計假說 2026-06-12
- 摩擦成本：第一次出現的教訓暫存 retro.md，可能延遲受益
- 鬆綁階梯：×2 → ×1（模型強到不受雜訊干擾時反而可放寬收錄）
- 挑戰條件：lessons 命中率數據（retro 統計）

## lessons-cap-30（## Lessons ≤ 30 條觸發蒸餾）
- 防範：同上（context 肥胖）
- 證據：設計假說 2026-06-12
- 摩擦成本：定期蒸餾人力（由 /retro 自動）
- 鬆綁階梯：30 → 50 → 不設限
- 挑戰條件：模型升級（context 抗干擾力提升）

## escalation-whitelist（六條外不得問人）
- 防範：自動化破功——弱模型遇含糊就丟回人類
- 證據：設計假說 2026-06-12
- 摩擦成本：decide-and-log 偶爾決策錯誤需收尾返工
- 鬆綁階梯：固定白名單 → 允許模型自判新增暫停類別
- 挑戰條件：decide-and-log 的決策錯誤率（retro 統計）

## human-merge-gate（harness 機制級變更必經人類核准）
- 防範：被測量的 agent 拆自己的煞車（Goodhart）
- 證據：對齊原則，**不可配置、不參與 ablation**
- 摩擦成本：極低頻（僅改 harness 時）
- 鬆綁階梯：無
- 挑戰條件：無
