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
- 已知缺口：allowlist 用 `-like`（不分大小寫），Linux FS 區分大小寫 → `Docs/`、`SRC/` 等變體會被 docs allowlist 放行（fail-open 方向，2026-06 跨平台移植 R1 審查接受為已知限制）
- 已知缺口：Linux 上 `\` 是合法檔名字元，ConvertTo-NativePath 會把名稱內的 `\` 改寫成分隔符 → 字面名含 `\` 的路徑可能混疊進 allowlist（fail-open 方向；2026-06 Phase 4 資安審查登記）
- 已知缺口：allowlist 前綴比對未做路徑正規化，`<root>/docs/../src/x` 形式可借 docs 前綴過閘（既有缺口非移植引入；與上一條同候選修法：比對前 `[IO.Path]::GetFullPath` 正規化，置於既有 fail-open try/catch 內）
- 2026-06 跨平台移植：allowlist 前綴改 `[WildcardPattern]::Escape` 組合（修復 root 含 `[ ]` 時比對失效——失效方向是誤鎖＝fail-closed，故屬正確性修復非鬆綁）

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

## human-merge-gate（受保護分支合併必經人類核准）
- 防範：被測量的 agent 拆自己的煞車（Goodhart）——發布用分支的內容只能由人類決策推進
- 受保護集合（操作型定義）：`config.git.protectedBranches`（calibrate 錨定，必含發布分支）∪ {存在的 `main`/`master`} ∪ {可解析的 `origin/HEAD`}；config 缺 `git` 節或清單空且 origin/HEAD 不可解析 → 視同全集（保守向）。**agent 只能擴集、不得縮集；預設分支恆在集內；操縱集合定義輸入（remote set-head、增刪/改指 remote、刪除或改名 main/master）視同縮集，一律禁止。**
- 閘門語意：受保護分支 ref 不得由 agent 以**任何方式**推進或破壞（merge／push／fast-forward／reset／branch -f／改名／刪除）；唯一途徑＝開 PR。**核准與合併皆為人類動作**——agent 不得執行或安排合併（`gh pr merge` 含 `--auto`、GitHub API、CI、排程、subagent 代行皆同；經代理推進視同本人）；**PR 開出後來源分支凍結**（需修改＝關閉重開或請人類重審）。開發/hotfix 類（＝受保護集合以外的一切分支）由 agent 主動分段 merge，**僅限綠階段**（自報錨點：red_count==0 且 HEAD==last_green_commit、片 verifier 已過；merge body 附全套測試指令＋exit code 供事後驗證）。
- 執法層（誠實記載）：**instruction 層**（harness-cycle skill＋CLAUDE.md），無 hook 攔截、無自動遙測事件；錨點欄位（red_count／last_green_commit）為 agent 自報、低於棘輪上限時無遙測——分段 merge 的「綠」最終仍是 instruction 層保證。config.json 縮集屬**事後稽核**（版控歷史可見），非即時防線。加固方向（機制級候選）：PreToolUse Bash matcher 攔 `git merge/push/reset` 比對受保護集合。
- 證據：對齊原則；2026-06-13 依使用者指示一般化（原為「機制級變更必經人類核准」）。**閘門存在性＋預設分支成員資格不可配置、不參與 ablation**。opus-harness 自身的機制級變更額外要求 bench A/B 後走本閘。
- 摩擦成本：低頻（發布時點）；分段 merge 使開發期零摩擦
- 鬆綁階梯：無（擴集屬 config、非鬆綁）
- 挑戰條件：無
