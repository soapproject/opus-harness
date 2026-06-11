# opus-harness hooks 共用函式。鐵律 fail-open：任何函式內部錯誤不得拋出致命例外。

function Find-HarnessDir {
  param([string]$StartDir, [string]$StopAt)
  try {
    $dir = $StartDir
    while ($dir) {
      $candidate = Join-Path $dir ".claude\harness"
      if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
      if ($StopAt -and ($dir -eq $StopAt)) { return $null }
      $parent = Split-Path $dir -Parent
      if (-not $parent -or $parent -eq $dir) { return $null }
      $dir = $parent
    }
  } catch {}
  return $null
}

function Read-HarnessJson {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
  } catch { return $null }
}

function Read-HookStdin {
  try {
    $sr = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))
    return $sr.ReadToEnd()
  } catch { return "" }
}

function Test-CycleActive {
  param($State)
  try {
    if ($null -eq $State) { return $false }
    $phaseVal = $State.PSObject.Properties['phase']
    if (-not $phaseVal) { return $false }
    if ($phaseVal.Value -eq "done") { return $false }
    if (-not $phaseVal.Value) { return $false }
    $suspendedProp = $State.PSObject.Properties['suspended']
    if ($suspendedProp -and $suspendedProp.Value) { return $false }
    return $true
  } catch { return $false }
}

function Write-Telemetry {
  param([string]$HarnessDir, [string]$Constraint, [string]$Event, [string]$Detail)
  try {
    if (-not $HarnessDir) { return }
    if (-not (Test-Path -LiteralPath $HarnessDir -PathType Container)) { return }
    $rec = [ordered]@{ ts = (Get-Date).ToUniversalTime().ToString("o"); constraint = $Constraint; event = $Event; detail = $Detail } | ConvertTo-Json -Compress
    $path = Join-Path $HarnessDir "telemetry.jsonl"
    $enc = New-Object System.Text.UTF8Encoding $false
    for ($i = 0; $i -lt 3; $i++) {
      try { [System.IO.File]::AppendAllText($path, $rec + [Environment]::NewLine, $enc); break }
      catch { Start-Sleep -Milliseconds (10 * ($i + 1)) }
    }
  } catch {}
}

function Update-StateField {
  param([string]$HarnessDir, [string]$Name, $Value)
  $tmp = $null
  try {
    $path = Join-Path $HarnessDir "state.json"
    $state = Read-HarnessJson $path
    if ($null -eq $state) { return }
    if ($state -isnot [System.Management.Automation.PSCustomObject]) { return }
    if ($state.PSObject.Properties[$Name]) { $state.$Name = $Value }
    else { $state | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
    $tmp = "$path.tmp-$PID"
    for ($i = 0; $i -lt 3; $i++) {
      try {
        Set-Content -LiteralPath $tmp -Value ($state | ConvertTo-Json -Depth 8) -Encoding utf8 -ErrorAction Stop
        Move-Item -LiteralPath $tmp -Destination $path -Force -ErrorAction Stop
        $tmp = $null
        break
      } catch { Start-Sleep -Milliseconds (10 * ($i + 1)) }
    }
  } catch {
    if ($tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
}
