BeforeAll {
  . "$PSScriptRoot\..\hooks\lib\harness-common.ps1"
  $script:fixture = Join-Path $env:TEMP ("oh-common-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Force (Join-Path $fixture ".claude\harness") | Out-Null
  New-Item -ItemType Directory -Force (Join-Path $fixture "src\deep") | Out-Null
}
AfterAll { Remove-Item -Recurse -Force $script:fixture -ErrorAction SilentlyContinue }

Describe "Find-HarnessDir" {
  It "find .claude\harness from subdirectory" {
    Find-HarnessDir (Join-Path $fixture "src\deep") | Should -Be (Join-Path $fixture ".claude\harness")
  }
  It "returns null when StopAt boundary reached before finding harness" {
    $fixture2 = Join-Path $env:TEMP ("oh-nofind-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $fixture2 "a\b") | Out-Null
    try {
      Find-HarnessDir (Join-Path $fixture2 "a\b") -StopAt $fixture2 | Should -BeNullOrEmpty
    } finally {
      Remove-Item -Recurse -Force $fixture2 -ErrorAction SilentlyContinue
    }
  }
}

Describe "Read-HarnessJson" {
  It "valid JSON returns object" {
    $p = Join-Path $fixture ".claude\harness\state.json"
    Set-Content $p '{"phase":"executing","red_count":1}' -Encoding utf8
    (Read-HarnessJson $p).phase | Should -Be "executing"
  }
  It "bad JSON returns null (fail-open)" {
    $p = Join-Path $fixture ".claude\harness\bad.json"
    Set-Content $p '{not json' -Encoding utf8
    Read-HarnessJson $p | Should -BeNullOrEmpty
  }
  It "missing file returns null" {
    Read-HarnessJson (Join-Path $fixture "nope.json") | Should -BeNullOrEmpty
  }
}

Describe "Test-CycleActive" {
  It "executing and not suspended is true" {
    Test-CycleActive ([pscustomobject]@{ phase = "executing"; suspended = $false }) | Should -BeTrue
  }
  It "suspended is false" {
    Test-CycleActive ([pscustomobject]@{ phase = "executing"; suspended = $true }) | Should -BeFalse
  }
  It "null state is false" {
    Test-CycleActive $null | Should -BeFalse
  }
  It "phase=done is false" {
    Test-CycleActive ([pscustomobject]@{ phase = "done"; suspended = $false }) | Should -BeFalse
  }
  It "state missing suspended property counts as active when phase is valid" {
    Test-CycleActive ([pscustomobject]@{ phase = "executing" }) | Should -BeTrue
  }
}

Describe "Write-Telemetry and Update-StateField" {
  It "telemetry appends one JSON line" {
    $dir = Join-Path $fixture ".claude\harness"
    Write-Telemetry -HarnessDir $dir -Constraint "stop-gate" -Event "block" -Detail "exit 1"
    $line = Get-Content (Join-Path $dir "telemetry.jsonl") | Select-Object -Last 1
    ($line | ConvertFrom-Json).constraint | Should -Be "stop-gate"
  }
  It "Update-StateField rewrites single field" {
    $dir = Join-Path $fixture ".claude\harness"
    Set-Content (Join-Path $dir "state.json") '{"phase":"executing","stop_block_count":0}' -Encoding utf8
    Update-StateField -HarnessDir $dir -Name "stop_block_count" -Value 2
    (Read-HarnessJson (Join-Path $dir "state.json")).stop_block_count | Should -Be 2
  }
  It "Update-StateField adds a new field and preserves existing fields" {
    $dir = Join-Path $fixture ".claude\harness"
    Set-Content (Join-Path $dir "state.json") '{"phase":"executing"}' -Encoding utf8
    Update-StateField -HarnessDir $dir -Name "red_count" -Value 3
    $s = Read-HarnessJson (Join-Path $dir "state.json")
    $s.red_count | Should -Be 3
    $s.phase | Should -Be "executing"
  }
  It "Write-Telemetry called twice produces 2 parseable JSON lines" {
    $dir2 = Join-Path $env:TEMP ("oh-tel-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $dir2 | Out-Null
    try {
      Write-Telemetry -HarnessDir $dir2 -Constraint "c1" -Event "e1" -Detail "d1"
      Write-Telemetry -HarnessDir $dir2 -Constraint "c2" -Event "e2" -Detail "d2"
      $lines = @(Get-Content (Join-Path $dir2 "telemetry.jsonl") | Where-Object { $_ -ne "" })
      $lines.Count | Should -Be 2
      ($lines[0] | ConvertFrom-Json).constraint | Should -Be "c1"
      ($lines[1] | ConvertFrom-Json).constraint | Should -Be "c2"
    } finally {
      Remove-Item -Recurse -Force $dir2 -ErrorAction SilentlyContinue
    }
  }
  It "Write-Telemetry with missing dir produces zero stderr and exits 0" {
    $libPath = "$PSScriptRoot\..\hooks\lib\harness-common.ps1"
    $stderrFile = Join-Path $env:TEMP ("oh-stderr-" + [guid]::NewGuid() + ".txt")
    try {
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = "powershell.exe"
      $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `". '$libPath'; Write-Telemetry -HarnessDir 'C:\definitely\missing\dir-xyz' -Constraint t -Event e -Detail d`""
      $psi.RedirectStandardError = $true
      $psi.RedirectStandardOutput = $true
      $psi.UseShellExecute = $false
      $proc = [System.Diagnostics.Process]::Start($psi)
      $stderrContent = $proc.StandardError.ReadToEnd()
      $proc.WaitForExit()
      $exitCode = $proc.ExitCode
      $proc.Dispose()
      $exitCode | Should -Be 0
      $stderrContent.Trim() | Should -BeNullOrEmpty
    } finally {
      if (Test-Path -LiteralPath $stderrFile) { Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue }
    }
  }
  It "Update-StateField on top-level array leaves file unchanged" {
    $dir = Join-Path $fixture ".claude\harness"
    $arrJson = '[1,2,3]'
    Set-Content (Join-Path $dir "state.json") $arrJson -Encoding utf8
    Update-StateField -HarnessDir $dir -Name "red_count" -Value 99
    $raw = Get-Content -LiteralPath (Join-Path $dir "state.json") -Raw
    $parsed = $raw | ConvertFrom-Json
    $parsed.Count | Should -Be 3
  }
}
