# 跨平台移植 實作計畫（v2，計畫審查後修訂）

cycle：20260612-xplat-port ｜ type：persistent ｜ spec：`.claude/harness/specs/2026-06-12-xplat-port.md`
分支策略：`cross-platform` 分支開發；完成後開 PR，**人類核准合併**（human-merge-gate）。
**嚴禁在分支 checkout 狀態下 `claude plugin update`**（會把未合併分支發佈到 live plugin，繞過合併閘）。

## Decisions

- gitignore 額外排除 state.json/telemetry.jsonl（calibrate.md 未涵蓋→retro 候選）
- [計畫審查 R1] 已安裝 plugin 為 SHA 釘選快取副本：working tree 改動不影響 live hooks → spec「空窗」風險改寫為「merge 後需 cutover（plugin update + 重啟）」
- [計畫審查 R1] 過渡期 config 用 pwsh 絕對路徑 → [S1 實測作廢] winget 裝的是 MSIX 變體，pwsh 在 WindowsApps（恆在 user PATH），裸 `pwsh` 全環境可解析——config 直接用裸 `pwsh`，S8 無需改回
- [計畫審查 R1] gate-ratchet 的 `-like` 未跳脫 `$root` 是既有缺陷（root 含 `[ ]` 即失效）：本次一併以 `[WildcardPattern]::Escape` 修復（觸碰同段程式碼的正確性修復，非語意變更）；`-like` 不分大小寫在 Linux 上對 `Docs/` 偏寬鬆＝**接受為已知限制**（fail-open 方向），記入 constraints.md
- [計畫審查 R1] G3 量測樣式改為抓**裸 `powershell`**（word-boundary），否則 runner.Tests/config 的無 .exe 引用漏網——spec 驗證表已同步修訂
- [S2 前] 教訓實例：用 PS 5.1 Get-Content（未帶 -Encoding utf8）讀寫無 BOM UTF-8 計畫檔導致全檔亂碼，自 context 重建——repo 文字檔的編輯一律用檔案工具，不用 shell 字串手術（retro 候選）
- [S2 驗證] 教訓實例：S2 verifier 與 S3 implementer 並行於同一 working tree → verifier 跑套件得到污染性假紅（16 紅 vs 靜止重跑 45 綠）。會執行測試的 verifier 不是純讀取操作，必須在 tree 靜止時跑或用隔離 worktree（retro 候選，harness 級）
- [S4 驗證] 教訓實例：S4 verifier 用 Windows PowerShell 5.1 host 跑套件得 17 紅（報告自述「the runner is Windows PowerShell 5.1」；T3 的 3-arg Join-Path 在 5.1 必紅），但 spec 邊界明文棄 5.1、G1 判準引擎是 pwsh。安靜樹 b4beacd 以規定指令重跑 = 46/46 exit 0 → 裁決 S4 通過。教訓：verifier 必須逐字執行 spec 驗證表的指令（含 shell 引擎），不得意譯或換引擎；與 S2 並行污染同屬「驗證環境保真」類（retro 候選，harness 級）
- [S4 後] 落實先前已記錄的 gitignore 決議（state.json/telemetry.jsonl 入 .gitignore）並補 git add 漏掉的 specs/（persistent 工件應入版控；plans/ 已入而 specs/ 漏了）
- [S7] 排序決定：S8 的 `gh pr create` 延後到 Phase 4 評分小組之後執行——PR 是給人類的結論卡，依「先自我審查、人類只收結論」原則，PR body 須附 scorecard 與 G1–G6 證據。S8 先完成 docs＋validate＋查核表（executing 收尾），再 phase→review 跑小組，最後開 PR 停等人類 merge
- [S7] Actions annotation：actions/checkout@v4 跑在 Node.js 20，2026-09-16 後 runner 移除 Node 20——非本 cycle 範圍，記為後續維護項（retro 候選）
- [Phase 4] 評分小組（全 diff 702fd2e..e36e512）：效能 9／可維護可讀 7／資安 8，**零 blocker、門檻（≥7）全過**。2 major＋11 minor。本輪即修：2 major 全修（bench.md 指令改 pwsh＋正斜線；新增 `tests/repo-conventions.Tests.ps1`（BOM＋禁 legacy 引擎兩條永久回歸測試，48→50），CLAUDE.md「測試有斷言」宣稱轉真）＋低成本 minor 四件（workflow `permissions: contents: read`、Pester 釘 5.7.1、constraints.md 登記 Linux 反斜線混疊＋前綴未正規化、calibrate.md 過期 5.1 理由改寫）。其餘 minor 緩議入 retro：gate-ratchet cwd 正規化一致性、lib Join-Path 慣用法統一、fixture helper 統一 -LiteralPath、payload builder 去重、CI module cache／trigger 範圍、bench.md 類執行性文件納入 G3 掃描。**hook 程式碼零變動**（保持小組審查時狀態）。
- [Phase 4] **重大發現：stop-gate 自 S2 起被無聲中和（永遠假綠）**。S2 將 config commands 寫成 `pwsh -NoProfile -Command "$r = ..."` 包裝形；gate-stop 以 `-EncodedCommand` 執行該字串時，外層 pwsh 先把雙引號內 `$r` 插值成空 → 內層收到 ` = Invoke-...; exit `，`=` 為非終止錯誤、裸 `exit` → **exit 0**（探針實證：WRAPPED=0、BARE=5）。state 的 stop_block_count=82 全為 S2 前累積。修復：config commands 改裸 pwsh 腳本文字；calibrate.md＋CLAUDE.md 增「commands＝pwsh 腳本文字，嚴禁再包一層 `pwsh -Command`」規則、校準時以 -EncodedCommand 同構驗證。retro 候選（harness 級）：①gate 自我測試 bench case（故意紅 repo 斷言 stop-gate 必擋）②約束無聲失效偵測（預期觸發卻長期零觸發 → 報警）。
- [Phase 4] 環境保真第三例：同一樹經 Git Bash 鏈跑套件得 5 紅（CJK 斷言因子行程編碼鏈差異假紅；PowerShell 工具暫時 EPERM 才改走 bash），規定 pwsh 指令重跑 50/50 綠。與 S2 並行污染、S4 錯引擎同類。retro 候選：測試 BeforeAll 統一設 console 編碼降低環境敏感。
- [Retro 更正] 先前判斷「stop_block_count=82 全為 S2 前累積」**錯誤**：telemetry 84 筆 block 全在 S2/S4 期間（03:41、04:03–08），且間隔僅 ~1.4s。修正後的全貌：S2 落地包裝形 config 當下（首筆 block 03:41:21 與 db2b188 同窗），hook 引擎尚為 powershell.exe 5.1，插值垃圾在 5.1 為**終止性錯誤 → exit 1 → 假紅狂擋**；S7 換 pwsh 7 後同字串變**非終止錯誤＋裸 exit → exit 0 → 假綠靜音**（探針 WRAPPED=0）。同一 bug 隨引擎雙向失效，兩種模式皆無人察覺。另：12–24 連發 burst 顯示 escape valve（block≥2 放行）可能未生效——列機制級調查項。

## Slices（依賴：S1→S2→S3→S4→S5→S6→S7→S8；G2 達成點在 S7）

### S1 環境前置：pwsh 7 ＋ pwsh 的 Pester 5
- [x] 行為：本機 pwsh 7 可執行且看得到 Pester 5（實測：pwsh 7.6.2 @ WindowsApps、Pester 5.7.1、裸名可解析）
- 檔案：無（環境變更）
- 步驟：`winget install --id Microsoft.PowerShell ...`；`pwsh -NoProfile -Command "Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck"`
- 驗收：`pwsh -NoProfile -Command "(Get-Module -ListAvailable Pester | Select-Object -First 1).Version.Major; $PSVersionTable.PSVersion.Major"` 輸出含 `5` 與 `7` ✅

### S2 hook/lib 測試檔改 pwsh ＋ config 引擎切換（自咬窗口處理）
- [x] 行為：三個 hook/lib 測試檔的 child invocation 改 pwsh、全綠；專案 config 同步切 pwsh（db2b188；紅證據：pwsh literal passing 使 5.1 式跳脫反向出錯 16 紅→修正→45 綠；驗證裁決記錄：verifier 與 S3 並行導致污染性假紅，靜止重跑 45/45——教訓入 Decisions）
- 檔案：`tests/gate-stop.Tests.ps1`、`tests/gate-ratchet.Tests.ps1`、`tests/harness-common.Tests.ps1`、`.claude/harness/config.json`
- 紅：`pwsh -NoProfile -Command "$r = Invoke-Pester -Path tests -PassThru -Output None; exit $r.FailedCount"`（從 cmd/bash 呼叫以免外層展開 `$r`）預期非 0，記錄實際紅項
- 改：child `powershell.exe` → `pwsh`；引數跳脫依 pwsh 實測修正（7.3+ literal passing）；**嚴禁削弱斷言**；config.json test/testQuick → 裸 `pwsh` 版
- 綠＝驗收：上式 exit 0（45）；三檔 `git grep -nE "\bpowershell(\.exe)?\b"` 無命中
- 內嵌 T1：Given 既有 45 測試，When pwsh 7 執行，Then 全綠

### S3 GitHub Actions linux-tests workflow（Linux 紅綠測試台）
- [x] 行為：push 即於 ubuntu-latest 以 pwsh 跑全套件（e450cb0；首跑 run 27393290930 = failure 如預期，紅項分類見文末記錄）
- 檔案：`.github/workflows/linux-tests.yml`
- 內容：`on: [push, pull_request]`；`runs-on: ubuntu-latest`；steps：`actions/checkout@v4` → `Install-Module Pester -Force -SkipPublisherCheck`（shell: pwsh）→ 跑套件（shell: pwsh，inline `$r = Invoke-Pester ...; exit $r.FailedCount`）
- 預期：首跑**紅**＝後續切片的紅階段證據，紅項清單記入本計畫
- 驗收：`gh run list --workflow linux-tests.yml --limit 1 --json status,conclusion` 回傳 completed 列；紅項已記錄於計畫
- 內嵌 T2（前半）：綠的驗收在 S7

### S4 lib＋gate-stop 平台中立＋gate-stop child→pwsh＋T3
- [x] 行為：harness-common 與 gate-stop 在兩平台正確（含 stop-gate 子行程引擎）（b4beacd；安靜樹 pwsh 重跑 46/46 綠；verifier 紅判定經裁決推翻，見 Decisions）
- 檔案：`hooks/lib/harness-common.ps1`、`hooks/gate-stop.ps1`、`tests/harness-common.Tests.ps1`
- 先加 T3：Given Find-HarnessDir 收到含正斜線的輸入路徑，When 探索，Then 找到 harness 目錄
- 改：字面值 `".claude\harness"` join → 兩段 Join-Path；新增 `ConvertTo-NativePath` helper（`/`、`\` → `[IO.Path]::DirectorySeparatorChar`），外部輸入路徑入口先過它；gate-stop 子行程 `powershell.exe -EncodedCommand` → `pwsh -EncodedCommand`（保留 -NonInteractive）
- 綠＝驗收：S2 的 G1 指令 exit 0（46）；`git grep -nE "\bpowershell(\.exe)?\b" -- hooks/lib hooks/gate-stop.ps1` 無命中；`git grep -E "claude\\\\harness" -- hooks` 無單字串字面值
- 內嵌 T3 全文如上

### S5 gate-ratchet 平台中立＋wildcard escape 修復＋T4
- [x] 行為：ratchet 正規化、allowlist 在兩平台正確且抗 `[ ]` 路徑（c3ab7c4；紅證據：T4b 紅——unescaped -like 把 `[1]` 當字元類；T4 本機綠如預期，Linux 紅證據在 CI；48/48 綠；verifier pass 零 blocker；其 minor＝New-Fixture 預設 $env:TEMP 屬 S6 範圍）
- 檔案：`hooks/gate-ratchet.ps1`、`tests/gate-ratchet.Tests.ps1`
- 先加 T4：Given 紅 ≥ limit 且 file_path 為平台中立構造的 `<root>/src/a.ts` 與 `<root>/docs/p.md`，Then src block（exit 2）、docs allow（exit 0）；加 T4b：root 含 `[1]` 的 fixture，allowlist 判斷仍正確
- 改：`-replace "/", "\"` → ConvertTo-NativePath；allowlist pattern 以 `[WildcardPattern]::Escape($root)` 組合＋平台分隔符
- 綠＝驗收：G1 指令 exit 0；`git grep -nE "\bpowershell(\.exe)?\b" -- hooks/gate-ratchet.ps1 tests/gate-ratchet.Tests.ps1` 無命中
- 內嵌 T4/T4b 全文如上

### S6 測試套件平台中立＋runner 引擎統一
- [x] 行為：四個測試檔與 runner 在 Linux 可執行（temp 路徑、stdin 測試、字面值分隔符、child 引擎）（b2fc5c5；$env:TEMP→GetTempPath ×18、反斜線字面值清零、F3 stdin 改 pipeline 且實證仍走 Read-HookStdin、runner 引擎→pwsh；48/48 綠；verifier pass 零 findings、It 數前後皆 48 無弱化；紅證據＝S3 Linux CI 紅基線）
- 檔案：`tests/gate-stop.Tests.ps1`、`tests/runner.Tests.ps1`、`bench/runner.ps1`
- 改：`$env:TEMP` → `[IO.Path]::GetTempPath()`（全部四檔，含 S2/S5 已動過的再掃一次）；gate-stop F3 的 `cmd /c "... < file"` stdin 測試 → 跨平台寫法（`Get-Content file -Raw | & pwsh -File gate` 或平台分支）；測試內 `".claude\harness"`、`"..\hooks\..."` 字面值 → Join-Path 組合；runner.ps1 child 與 `$AgentCommand` 預設 `powershell`→`pwsh`；runner.Tests 的裸 `powershell` 全改
- 綠＝驗收：G1 指令 exit 0（48）；`git grep -nE "\bpowershell(\.exe)?\b" -- tests bench` 無命中
- 內嵌 T5（文件化項，S8 寫 README）

### S7 hooks.json→pwsh → Linux 全綠（G2 達成）
- [x] 行為：hook 佈線改 pwsh、全 repo G3/G4 歸零、Actions 綠（db212b9；G3/G4 grep 零命中、G1 48/48；**G2 達成**：run 27431698931 success，log 確認 Tests Passed: 48, Failed: 0, Skipped: 0 @ ubuntu-latest 18.46s；本片 2 行佈線由主迴圈直做，新鮮視角驗證＝ubuntu CI 本身＋Phase 4 全 diff 評分小組）
- 檔案：`hooks/hooks.json`
- 改：command `powershell.exe ... \\hooks\\gate-*.ps1` → `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/hooks/gate-*.ps1"`（正斜線兩平台皆通）
- 驗收：`git grep -nE "\bpowershell(\.exe)?\b" -- hooks bench tests` 無命中（G3）；`git grep -lE "claude\\\\harness" -- "*.ps1"` 無輸出（G4）；G1 exit 0；push → `gh run list --workflow linux-tests.yml --limit 1 --json conclusion` = success（**G2**）
- 注意：live plugin 為快取副本，本片不影響使用者現行 hooks（cutover 在 merge 後）

### S8 文件＋最終驗證＋PR（G5/G6）
- [x] 行為：README 雙平台安裝；六目標查核；PR 開立（e36e512 docs＋4ea7ba8 review fixes；validate 過；G1=50/50、G2=run 27433012413 success（Linux 50/0/0）、G3/G4 grep 零＋已測試化、G6 Windows 4 步/Ubuntu 5 步；**PR #1 已開**：https://github.com/soapproject/opus-harness/pull/1 ——停等人類 merge）
- 檔案：`README.md`、`CLAUDE.md`
- 改：README 安裝節加 Ubuntu（≤5 步：CLI、snap pwsh、marketplace add、install、重啟）與 Windows（winget pwsh + 既有流程）；註明 macOS 未實測、無 pwsh = hooks 非阻斷錯誤（fail-open）、**merge 後 cutover：master checkout → `claude plugin marketplace update opus-harness-local` → 重裝/重啟，嚴禁 branch 狀態 update**；CLAUDE.md house rule：pwsh 為唯一 hook 引擎
- 驗收：`claude plugin validate .` 通過；G1–G6 查核表逐項打勾附證據；`gh pr create`（base master、head cross-platform，body 附證據）——**停在等人類 merge（wrapup 前最後回報）**

### S3 首跑紅項記錄（databaseId: 27393290930, conclusion: failure）

**總計：Passed: 2 / Failed: 43 / Container failed: 3**
綠了的測試：gate-ratchet "no harness dir exits 0"、gate-stop "no harness dir exits 0"

#### 根本原因分類

**類型 A：`$env:TEMP` 在 ubuntu-latest 為 null/空（所有 4 個測試檔）**
- ubuntu-latest 的 pwsh 環境中 `$env:TEMP` 未設定（Linux 用 `$TMPDIR` 或 `/tmp`）
- `Join-Path $env:TEMP "oh-xxx-<guid>"` 回傳 null → New-Fixture 的 `-Path` 參數收到 null → `ParameterBindingValidationException`
- 影響的測試容器：`gate-ratchet.Tests.ps1`、`gate-stop.Tests.ps1`、`harness-common.Tests.ps1`、`runner.Tests.ps1`
- 修復方向（S6）：`$env:TEMP` → `[IO.Path]::GetTempPath()`（跨平台 API）

**類型 B：PSScriptRoot 內的反斜線硬碼路徑（hook 與 lib 載入）**
- `"$PSScriptRoot\..\hooks\gate-ratchet.ps1"` 等路徑在 Linux 下 `\` 非分隔符，導致路徑解析失敗
- 影響：`harness-common.Tests.ps1` (`. "$PSScriptRoot\..\hooks\lib\harness-common.ps1"`)、`gate-ratchet.Tests.ps1`、`gate-stop.Tests.ps1`
- 修復方向（S4/S6）：改用 `Join-Path $PSScriptRoot ".." "hooks" "..."` 或 `[IO.Path]::Combine`

**類型 C：New-Fixture 內部 Join-Path 的反斜線路徑字面值**
- `Join-Path $f ".claude\harness"` 等含 `\` 的字串，在 Linux 被當作單一路徑段而非多段
- 修復方向（S6）：分解為多段 `Join-Path $f ".claude" "harness"`

**類型 D：gate-ratchet.Tests.ps1 BeforeAll 中 `$Root` 參數傳入 gate 的方式**
- gate-ratchet 的 Invoke-Gate 呼叫 pwsh 時未傳 `-Root $Fixture`；New-Fixture 的 `-Root` 參數不影響根本的 `$env:TEMP` 問題
- 但 `$env:TEMP` null 後 `$Root` fallback 觸發 null path → 覆蓋於類型 A

#### 紅項清單（測試名 → 失敗原因）

| 測試名 | 來源檔 | 失敗類型 |
|---|---|---|
| red_count below limit exits 0 | gate-ratchet | A + C（New-Fixture path null） |
| red_count at limit exits 2 with ratchet message and telemetry | gate-ratchet | A + C |
| harness path is whitelisted exits 0 | gate-ratchet | A + C |
| docs path is whitelisted exits 0 | gate-ratchet | A + C |
| phase review with high red_count exits 0 | gate-ratchet | A + C |
| block message contains CJK 鎖定 | gate-ratchet | A + C |
| notebook_path target with red=2 exits 2 | gate-ratchet | A + C |
| default limit 2: no voting config, red=2 exits 2 | gate-ratchet | A + C |
| harness-edit-allowed audit: red=2 edit harness file → exit 0 and telemetry event=harness-edit-allowed | gate-ratchet | A + C |
| anchoring: docs in ancestor path does not bypass ratchet for src edit | gate-ratchet | A + C |
| no last_green_commit: red=2 edit src → exit 2 and message matches 尚無綠點 | gate-ratchet | A + C |
| suspended state exits 0 even if test would fail | gate-stop | A + C |
| corrupt state exits 0 (fail-open) | gate-stop | A + C |
| phase plan exits 0 | gate-stop | A + C |
| no test command exits 0 with fail-open warning | gate-stop | A + C |
| testQuick passes resets stop_block_count to 0 | gate-stop | A + C |
| testQuick fails exits 2 and records telemetry and increments stop_block_count | gate-stop | A + C |
| escape valve fires when stop_hook_active and block_count >= 2 | gate-stop | A + C |
| quoted command args preserved - exit 2 and output matches 'a b' | gate-stop | A + C |
| CJK text appears in block message | gate-stop | A + C |
| stdin path: payload via piped stdin triggers block | gate-stop | A + C |
| valve boundary: block_count=2 stop_hook_active=false still blocks (exit 2) | gate-stop | A + C |
| valve boundary: block_count=1 stop_hook_active=true still enforces (exit 2) | gate-stop | A + C |
| harness-common.Tests.ps1（全容器）| harness-common | A + B（dot-source 路徑 null） |
| runner.Tests.ps1（全容器） | runner | A（$env:TEMP → null Path） |

**行動項（輸入至 S4–S6）：**
- S4/S5：`hooks/lib/harness-common.ps1`、`hooks/gate-stop.ps1`、`hooks/gate-ratchet.ps1` 路徑中立
- S6（主要修復批）：四個 tests 檔中的 `$env:TEMP` 全換 `[IO.Path]::GetTempPath()`；`.claude\harness` 等字面分隔符改 `Join-Path` 多段；`$PSScriptRoot\..\hooks\...` 改 `Join-Path $PSScriptRoot ".." "hooks" "..."`