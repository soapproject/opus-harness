# merge 政策 實作計畫（v2，計畫審查後修訂；persistent——憲法級變更留檔）

任務（使用者 2026-06-13 指派，原話）：「微調一下插件中關於merge的指示 改成要指定受保護的分支, 如果是發布用的branch比如main只能人類決策merge 不過如果是開發或hotfix類的branch應該要主動分段merge, message要寫why不是what方便agent追蹤 如果要詳細說明可以用臨時性質的claude.md傳遞」

類型：機制級 → 分支 `merge-policy`、PR 給人類 merge。bench A/B degenerate（golden set 尚無 case，誠實記錄）。

## 設計（v2，含審查修訂）

- **受保護集合（操作型定義）**＝`config.git.protectedBranches` ∪ {存在的 `main`/`master`} ∪ {可解析的 `origin/HEAD`}。config 缺 `git` 節 → 視同上述全集（保守向）。agent 只能**擴集不能縮集**；預設分支恆在集內。
- **閘門語意**：受保護分支 ref **不得以任何方式由 agent 推進或破壞**（merge／push／fast-forward／reset／branch -f／改名／刪除），唯一途徑＝開 PR、人類核准。此非「升級提問」而是常設閘門：開 PR 後停等，與升級白名單、stop-gate 無碰撞（發生於 wrapup 之後）。
- **分支分類（白名單法）**：受保護集合內＝發布用；其餘一律視為開發/hotfix 類。**行為由 cycle 啟動分支推導**：啟動於受保護分支 → 切短命 feature 分支、cycle 末 PR 回啟動分支；啟動於非保護分支 → 該分支即整合目標，feature 分支階段綠就主動分段 merge 回去。`config.git.integrationBranch` 僅為顯式 override，**且不得屬受保護集合**——衝突時視同未設定並升級告知。
- **分段 merge 紀律**：只准 merge 綠的階段（機械錨點：`red_count`==0 且 HEAD==`last_green_commit`，片 verifier 已過）。手法：`git merge --no-ff --no-commit` → 解衝突（屬程式碼工作，回 TDD 紀律）→ 跑 config 全套測試 → 綠才 commit merge，否則 `git merge --abort`。棘輪 reset --hard 只動 feature 分支，永不改寫整合分支。整合分支＝Phase 4 小組前的 WIP 整合層；panel blocker 以 fix-forward 新階段修復；受保護分支 PR 只在 panel 過後開。整合分支含未經人類核准變更——從其 checkout 跑 plugin update 仍屬 cutover 禁令範圍。
- **merge message 寫 why 不寫 what，且自含**：`merge(<topic>): <一句 why>`＋body 3–6 行（解什麼問題／為何此作法／捨棄了什麼）。**不引用任何檔案路徑**（ephemeral 工件會消失、persistent 工件會搬家）。what 由 diff 自證。
- **臨時 CLAUDE.md（細節傳遞）**：`.claude/harness/tmp/merge-<topic>.md`＝cycle 內給 subagent 的傳遞媒介（背景/取捨/風險），**永不被持久工件引用**；wrapup 蒸餾要點回計畫 Decisions 後刪除。本 repo `.gitignore` 補 `.claude/harness/tmp/`（審查發現：目前只是 untracked，一次 add -A 就進版控）。
- **執法層誠實登記**：本閘門為 **instruction 層**（skill＋CLAUDE.md 文字），無 hook 攔截、無自動遙測。實際防線＝config.json 已入版控（縮集會現形於 PR diff 人審）＋retro 稽核。加固方向（後續機制級候選）：PreToolUse Bash matcher 攔 `git merge/push` 比對受保護集合。
- **proportionality（決定並記錄）**：docs+schema 純文字，不開完整 state-machine cycle；計畫審查 1 人（已執行，2 blocker 6 major 4 minor 全數採納）；執行後審查 2 人＝maintainability＋**閘門措辭 adversarial（資安視角）**——本變更的攻擊面就是文字，資安維度不可省。

## Slices

### S1 閘門定義層
- [ ] `templates/config.schema.json`：新增 `git` 節——`protectedBranches`（array of string，default ["main","master"]；description：預設分支恆受保護、agent 只增不減）＋`integrationBranch`（string，default ""；description：顯式 override、不得屬受保護集合，衝突視同未設定並升級）
- [ ] `.claude/harness/config.json`（本 repo）：加 `"git": { "protectedBranches": ["master"], "integrationBranch": "" }`
- [ ] `.gitignore`（本 repo）：補 `.claude/harness/tmp/`
- [ ] `constraints.md`：human-merge-gate 條目改寫——標題一般化（受保護分支合併閘）；防範不變（Goodhart）；操作型受保護集合定義；「不得以任何方式推進/破壞 ref」語意；綠階段才可分段 merge＋不得縮集兩條硬規則折入登記；執法層誠實記載（instruction 層、無 hook、防線=版控 diff＋retro）；加固方向列 PreToolUse Bash matcher；**閘門存在性＋預設分支成員資格不可配置、不參與 ablation**（性質保留）；opus-harness 自身機制級變更額外要求 bench A/B
- 驗收：兩個 JSON `ConvertFrom-Json` 解析過；schema 與 config 欄位一致

### S2 指示層
- [ ] `skills/harness-cycle/SKILL.md`：新增「## 分支與合併策略」節（設計第 1–6 點全文：集合定義、啟動分支推導、分段 merge 紀律與機械錨點、message 格式、tmp 傳遞媒介、Phase 4 時序與 cutover 交叉引用、與升級白名單的關係=交叉引用非子案例）；Phase 3 表補「階段綠＋verifier 過 → 依分支策略分段 merge」
- [ ] `CLAUDE.md`：house rules——①merge message 寫 why 不寫 what 且自含 ②受保護分支 agent 禁推進 ref、只開 PR ③分段 merge 只准綠階段
- [ ] `README.md` 迭代協定行：受保護分支語意＋分段 merge 摘要
- [ ] `commands/bench.md`：「人類核准合併」措辭 → 受保護分支閘
- [ ] `commands/calibrate.md`：步驟 5 欄位同步＋「config.json 範例（完整形）」補 `git` 節（完整 config 消費者契約）
- [ ] `skills/adversarial-review/SKILL.md`：severity 定義消歧——「不擋合併安全」明確為「不擋受保護分支 PR」（分段 merge 的閘=片 verifier＋綠測試）
- [ ] `commands/cycle.md`：前置檢查 #4 殘留清理併入 `tmp/merge-*.md`
- 驗收：`claude plugin validate .` 過；全套件 50/50；`git grep -n "人類核准合併"` 僅歷史工件（plans/done/、specs/）留存

## Decisions

- bench A/B degenerate：golden set 空 → 本次閘門＝分支＋人類 PR 閘（首個 bench case 仍待打包）
- 歷史工件（plans/done/、specs/）不回改
- 計畫審查 R1（1 人唱反調）：2 blocker（integrationBranch×保護集合互斥缺失；空預設讀錯使用者需求→改啟動分支推導）＋6 major（tmp 未 ignore、保護集合無法判定、執法層未誠實登記、引用鏈自毀→message 自含、calibrate 契約漏改、審查維度砍錯）＋4 minor——全數採納入 v2

## 驗收總表

| 項 | 指令 | 預期 |
|---|---|---|
| JSON 健全 | `ConvertFrom-Json`（schema＋config） | 無錯 |
| plugin 完整 | `claude plugin validate .` | pass |
| 套件不退化 | G1 指令 | 50/50 exit 0 |
| 措辭一致 | `git grep -n "人類核准合併" -- "*.md"` | 僅 plans/done/、specs/ |
