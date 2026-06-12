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
