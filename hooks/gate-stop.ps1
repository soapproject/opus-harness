param([string]$StdinJson)

. (Join-Path $PSScriptRoot "lib\harness-common.ps1")

try {
  try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
  if (-not $StdinJson) { $StdinJson = Read-HookStdin }
  $payload = $null
  try { $payload = $StdinJson | ConvertFrom-Json } catch {}
  $cwd = $null
  if ($payload -and $payload.cwd) { $cwd = $payload.cwd } else { $cwd = (Get-Location).Path }

  $harnessDir = Find-HarnessDir $cwd
  if (-not $harnessDir) { exit 0 }
  $state = Read-HarnessJson (Join-Path $harnessDir "state.json")
  if (-not (Test-CycleActive $state)) { exit 0 }
  if ($state.phase -ne "executing") { exit 0 }

  $config = Read-HarnessJson (Join-Path $harnessDir "config.json")
  $cmd = $null
  if ($config -and $config.commands) {
    if ($config.commands.testQuick) { $cmd = $config.commands.testQuick }
    elseif ($config.commands.test) { $cmd = $config.commands.test }
  }
  if (-not $cmd) {
    [Console]::Error.WriteLine("[opus-harness stop-gate] config 缺 test/testQuick，放行（fail-open）。請補 /opus-harness:calibrate")
    Write-Telemetry -HarnessDir $harnessDir -Constraint "stop-gate" -Event "fail-open" -Detail "no test command"
    exit 0
  }

  $blockCount = 0
  if ($state.PSObject.Properties["stop_block_count"]) { $blockCount = [int]$state.stop_block_count }
  if ($payload -and $payload.stop_hook_active -and $blockCount -ge 2) {
    [Console]::Error.WriteLine("[opus-harness stop-gate] 連續 block 已達上限，放行（fail-open 逃生閥）。測試仍為紅，請人工確認。")
    Write-Telemetry -HarnessDir $harnessDir -Constraint "stop-gate" -Event "fail-open-escape" -Detail "block_count=$blockCount"
    exit 0
  }

  $slice = ""
  if ($state.PSObject.Properties["active_slice"]) { $slice = $state.active_slice }

  $projectRoot = Split-Path (Split-Path $harnessDir -Parent) -Parent
  $b64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
  Push-Location $projectRoot
  try {
    $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $b64 2>&1 | ForEach-Object { "$_" } | Out-String
    $code = $LASTEXITCODE
  } finally { Pop-Location }

  if ($code -eq 0) {
    Update-StateField -HarnessDir $harnessDir -Name "stop_block_count" -Value 0
    exit 0
  }

  Update-StateField -HarnessDir $harnessDir -Name "stop_block_count" -Value ($blockCount + 1)
  Write-Telemetry -HarnessDir $harnessDir -Constraint "stop-gate" -Event "block" -Detail "exit=$code slice=$slice"
  $tail = ($output -split "`n" | Select-Object -Last 50) -join "`n"
  [Console]::Error.WriteLine("[opus-harness stop-gate] 驗證指令失敗（exit $code），不得宣稱完成。修復失敗或 infra 壞掉時用 /opus-harness:cycle pause。失敗輸出（尾 50 行）：`n$tail")
  exit 2
} catch {
  [Console]::Error.WriteLine("[opus-harness stop-gate] 內部錯誤，放行（fail-open）：$($_.Exception.Message)")
  exit 0
}
