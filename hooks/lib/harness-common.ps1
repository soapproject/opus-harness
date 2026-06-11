# opus-harness hooks 共用函式。鐵律 fail-open：任何函式內部錯誤不得拋出致命例外。

function Find-HarnessDir {
  param([string]$StartDir)
  try {
    $dir = $StartDir
    while ($dir) {
      $candidate = Join-Path $dir ".claude\harness"
      if (Test-Path $candidate -PathType Container) { return $candidate }
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
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    return (Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
  } catch { return $null }
}

function Test-CycleActive {
  param($State)
  if ($null -eq $State) { return $false }
  if ($State.suspended) { return $false }
  if (-not $State.phase) { return $false }
  if ($State.phase -eq "done") { return $false }
  return $true
}

function Write-Telemetry {
  param([string]$HarnessDir, [string]$Constraint, [string]$Event, [string]$Detail)
  try {
    $rec = @{
      ts = (Get-Date).ToUniversalTime().ToString("o")
      constraint = $Constraint
      event = $Event
      detail = $Detail
    } | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $HarnessDir "telemetry.jsonl") -Value $rec -Encoding utf8
  } catch {}
}

function Update-StateField {
  param([string]$HarnessDir, [string]$Name, $Value)
  try {
    $path = Join-Path $HarnessDir "state.json"
    $state = Read-HarnessJson $path
    if ($null -eq $state) { return }
    if ($state.PSObject.Properties[$Name]) { $state.$Name = $Value }
    else { $state | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
    Set-Content -Path $path -Value ($state | ConvertTo-Json -Depth 8) -Encoding utf8
  } catch {}
}
