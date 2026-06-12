# opus-harness 開發守則

- Commit 前必跑：`pwsh -NoProfile -Command '$r = Invoke-Pester -Path tests -PassThru -Output Detailed; exit $r.FailedCount'`，全綠才准 commit。**-Command 引數一律單引號**——雙引號會被外層 shell（pwsh/bash 皆然）先插值 `$r` 成空字串，淪為永遠 exit 0 的假綠（與 config 包裝形同一 bug 類，2026-06-12 實證）。
- hook 腳本鐵律：**fail-open**——任何異常（缺檔、壞 JSON、自身錯誤）一律 exit 0 放行並寫 stderr 警告；只有明確判定違規才 exit 2。
- 任何新增/修改硬閘行為，必須同步更新 `constraints.md` 登記（無登記的約束不得上線）。
- 機制級變更（hook、流程、config schema）合併前先對 golden set 跑 `/opus-harness:bench`，結果存 `bench/results/`。
- **pwsh（PowerShell 7+）是唯一引擎**：hooks、測試、bench 子行程一律 `pwsh`，永不 `powershell.exe`；pwsh-only 語法（3-arg `Join-Path` 等）可用。Windows PowerShell 5.1 不支援（2026-06 跨平台移植定案）。
- 路徑一律平台中立：禁止反斜線字面值（如 `".claude\harness"`、`"$PSScriptRoot\lib\..."`），用多段 `Join-Path` 組合；外部輸入路徑入口先過 lib 的 `ConvertTo-NativePath`；temp 用 `[IO.Path]::GetTempPath()`，禁 `$env:TEMP`（Linux 上未設定）。
- `-like` 比對的路徑前綴一律 `[WildcardPattern]::Escape`（防 `[ ]` 等萬用字元路徑）。
- 所有 `.ps1` 一律存成 UTF-8 **with BOM**（專案既定慣例，`tests/repo-conventions.Tests.ps1` 有斷言；防工具鏈誤判編碼）；會輸出中文到 stdout/stderr 的腳本開頭先設 `[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false`。
- harness config 的 `commands.*` 是 **pwsh 腳本文字**（stop-gate 用 `pwsh -EncodedCommand` 原樣執行）：原生指令列（`npm test`）可直接放；PowerShell 內建寫裸腳本文字（`$r = Invoke-Pester ...; exit $r.FailedCount`）。**嚴禁再包一層 `pwsh -Command "..."`**——外層執行時先插值 `$` 變數，實測會把指令變成永遠 exit 0 的 no-op（2026-06-12 dogfooding 實證，stop-gate 因此被無聲中和）。
- 檔案系統操作一律 `-LiteralPath` ＋ `-ErrorAction Stop`（在 try/catch 內）；狀態檔寫入用 temp+Move-Item 原子交換。
- hook 讀 stdin 一律用 lib 的 Read-HookStdin（強制 UTF-8 解碼）；執行外部指令字串用 -EncodedCommand（防引號剝離）。
- 發版的 version bump（`.claude-plugin/plugin.json`）必須是**發版 PR 分支上 merge 前的最後一個 commit**——不得 merge 後在 master 補 commit（受保護分支 agent 不得推進）。不 bump 等於沒發佈：`claude plugin update` 以版本號判斷新舊，cutover 不會生效（2026-06-13 實證）。
- 受保護分支（`config.git.protectedBranches` ∪ 存在的 main/master ∪ origin/HEAD；本 repo＝master）：agent 不得推進其 ref，只能開 PR；**核准與合併皆人類動作**（gh pr merge／--auto／API／CI／subagent 代行皆禁，PR 開出後來源分支凍結）。開發/hotfix 類分支（其餘一切）＝綠階段主動分段 merge（細節見 harness-cycle skill「分支與合併策略」）。
- merge message 寫 **why** 不寫 what 且自含（`merge(<topic>): <一句 why>`＋3–6 行 body：解什麼問題／為何此作法／捨棄了什麼＋全套測試指令與 exit code）；不引用會消失或搬家的檔案路徑。分段 merge 只准綠階段（自報錨點：red_count==0、HEAD==last_green_commit、verifier 過）。

## Lessons

- [2026-06-13 ×2 @fable-5] 當編輯含非 ASCII 的 repo 文字檔時，一律用編輯器級檔案工具（Read/Edit/Write），禁止 shell 字串手術（無 -Encoding 的 Get-Content/Set-Content 重寫）（因為兩次中文亂碼事故——T4 期 BOM 缺失、S2 前計畫檔全毀——都是 shell 重寫造成）。
