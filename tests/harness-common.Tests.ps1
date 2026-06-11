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
  It "return null when not found" {
    Find-HarnessDir $env:TEMP | Should -BeNullOrEmpty
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
}
