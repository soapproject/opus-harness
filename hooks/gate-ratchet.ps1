param([string]$StdinJson)

. (Join-Path $PSScriptRoot "lib" "harness-common.ps1")

try {
  try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
  if (-not $StdinJson) { $StdinJson = Read-HookStdin }
  $payload = $null
  try { $payload = $StdinJson | ConvertFrom-Json } catch {}
  if (-not $payload) { exit 0 }
  $cwd = $null
  if ($payload.cwd) { $cwd = $payload.cwd } else { $cwd = (Get-Location).Path }

  $harnessDir = Find-HarnessDir $cwd
  if (-not $harnessDir) { exit 0 }
  $state = Read-HarnessJson (Join-Path $harnessDir "state.json")
  if (-not (Test-CycleActive $state)) { exit 0 }
  if ($state.phase -ne "executing") { exit 0 }

  $limit = 2
  $config = Read-HarnessJson (Join-Path $harnessDir "config.json")
  if ($config -and $config.PSObject.Properties["voting"] -and $config.voting -and $config.voting.PSObject.Properties["ratchetLimit"] -and $config.voting.ratchetLimit) { $limit = [int]$config.voting.ratchetLimit }
  $red = 0
  if ($state.PSObject.Properties["red_count"]) { $red = [int]$state.red_count }
  if ($red -lt $limit) { exit 0 }

  $target = $null
  if ($payload.PSObject.Properties["tool_input"] -and $payload.tool_input) {
    if ($payload.tool_input.PSObject.Properties["file_path"] -and $payload.tool_input.file_path) { $target = $payload.tool_input.file_path }
    elseif ($payload.tool_input.PSObject.Properties["notebook_path"] -and $payload.tool_input.notebook_path) { $target = $payload.tool_input.notebook_path }
  }
  if (-not $target) { exit 0 }
  $norm = ConvertTo-NativePath $target

  $root = Split-Path (Split-Path $harnessDir -Parent) -Parent
  $harnessPrefix = Join-Path $root ".claude" "harness"
  if ($norm -like ([WildcardPattern]::Escape($harnessPrefix) + [IO.Path]::DirectorySeparatorChar + '*')) {
    Write-Telemetry -HarnessDir $harnessDir -Constraint "ratchet" -Event "harness-edit-allowed" -Detail "red=$red target=$norm"
    exit 0
  }
  $docsPrefix = Join-Path $root "docs"
  if ($norm -like ([WildcardPattern]::Escape($docsPrefix) + [IO.Path]::DirectorySeparatorChar + '*')) { exit 0 }

  $slice = ""
  if ($state.PSObject.Properties["active_slice"]) { $slice = $state.active_slice }
  $green = ""
  if ($state.PSObject.Properties["last_green_commit"]) { $green = $state.last_green_commit }
  Write-Telemetry -HarnessDir $harnessDir -Constraint "ratchet" -Event "block" -Detail "red=$red slice=$slice target=$norm"
  if ($green) {
    [Console]::Error.WriteLine("[opus-harness ratchet] 本片 '$slice' 已紅 $red 次（上限 $limit），源碼編輯已鎖定。唯一出路：1) git stash  2) git reset --hard $green  3) 回計畫把本片切更小（更新計畫檔）  4) 將 state.json 的 red_count 歸零後重新開始本片。禁止繼續原地修補。")
  } else {
    [Console]::Error.WriteLine("[opus-harness ratchet] 本片 '$slice' 已紅 $red 次（上限 $limit），源碼編輯已鎖定。尚無綠點 commit：1) git stash 保留現場  2) 回計畫把本片切更小  3) red_count 歸零後重啟本片。禁止繼續原地修補。")
  }
  exit 2
} catch {
  [Console]::Error.WriteLine("[opus-harness ratchet] 內部錯誤，放行（fail-open）：$($_.Exception.Message)")
  exit 0
}
