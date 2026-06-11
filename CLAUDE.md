# opus-harness 開發守則

- Commit 前必跑：`Invoke-Pester -Path tests -Output Detailed`，全綠才准 commit。
- hook 腳本鐵律：**fail-open**——任何異常（缺檔、壞 JSON、自身錯誤）一律 exit 0 放行並寫 stderr 警告；只有明確判定違規才 exit 2。
- 任何新增/修改硬閘行為，必須同步更新 `constraints.md` 登記（無登記的約束不得上線）。
- 機制級變更（hook、流程、config schema）合併前先對 golden set 跑 `/opus-harness:bench`，結果存 `bench/results/`。
- Windows PowerShell 5.1 相容：禁用 `&&`、`||`、`??`、`?.`、ternary；檔案輸出一律 `-Encoding utf8`。
- 所有 `.ps1` 一律存成 UTF-8 **with BOM**（PS 5.1 無 BOM 會把中文讀成亂碼）；會輸出中文到 stdout/stderr 的腳本開頭先設 `[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false`。
- 檔案系統操作一律 `-LiteralPath` ＋ `-ErrorAction Stop`（在 try/catch 內）；狀態檔寫入用 temp+Move-Item 原子交換。
