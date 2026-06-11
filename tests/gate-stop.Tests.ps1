BeforeAll {
  $script:gate = "$PSScriptRoot\..\hooks\gate-stop.ps1"
  function New-Fixture {
    param([string]$StateJson, [string]$ConfigJson)
    $f = Join-Path $env:TEMP ("oh-stop-" + [guid]::NewGuid())
    $h = Join-Path $f ".claude\harness"
    New-Item -ItemType Directory -Force $h | Out-Null
    if ($StateJson) { Set-Content (Join-Path $h "state.json") $StateJson -Encoding utf8 }
    if ($ConfigJson) { Set-Content (Join-Path $h "config.json") $ConfigJson -Encoding utf8 }
    return $f
  }
  function Invoke-Gate {
    param([string]$Fixture, [string]$PayloadJson)
    $escapedJson = $PayloadJson -replace '"', '\"'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:gate -StdinJson $escapedJson 2>&1
    return @{ Code = $LASTEXITCODE; Text = ($out | Out-String) }
  }
}

AfterAll {
  Get-ChildItem $env:TEMP -Filter "oh-stop-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "gate-stop" {
  It "no harness dir exits 0" {
    $r = Invoke-Gate -Fixture $env:TEMP -PayloadJson ('{"cwd":"' + ($env:TEMP -replace '\\','\\') + '","stop_hook_active":false}')
    $r.Code | Should -Be 0
  }

  It "suspended state exits 0 even if test would fail" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":true}' `
      -ConfigJson '{"commands":{"test":"exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "corrupt state exits 0 (fail-open)" {
    $f = New-Fixture -StateJson '{broken' -ConfigJson '{"commands":{"test":"exit 0"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "phase plan exits 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"plan","suspended":false}' `
      -ConfigJson '{"commands":{"test":"exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "no test command exits 0 with fail-open warning" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false}' `
      -ConfigJson '{"commands":{}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
    $r.Text | Should -Match "stop-gate"
    $telemetryPath = Join-Path $f ".claude\harness\telemetry.jsonl"
    Test-Path $telemetryPath | Should -BeTrue
    $lastEvent = Get-Content $telemetryPath | Select-Object -Last 1 | ConvertFrom-Json
    $lastEvent.event | Should -Be "fail-open"
  }

  It "testQuick passes resets stop_block_count to 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":1}' `
      -ConfigJson '{"commands":{"testQuick":"exit 0"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
    $stateRaw = Get-Content (Join-Path $f ".claude\harness\state.json") -Raw | ConvertFrom-Json
    $stateRaw.stop_block_count | Should -Be 0
  }

  It "testQuick fails exits 2 and records telemetry and increments stop_block_count" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":0}' `
      -ConfigJson '{"commands":{"testQuick":"Write-Output BOOM; exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "stop-gate"
    $r.Text | Should -Match "BOOM"
    $r.Text | Should -Match "驗證指令失敗"
    $telemetryPath = Join-Path $f ".claude\harness\telemetry.jsonl"
    Test-Path $telemetryPath | Should -BeTrue
    $stateRaw = Get-Content (Join-Path $f ".claude\harness\state.json") -Raw | ConvertFrom-Json
    $stateRaw.stop_block_count | Should -Be 1
  }

  It "escape valve fires when stop_hook_active and block_count >= 2" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":2}' `
      -ConfigJson '{"commands":{"testQuick":"exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":true}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
    $telemetryPath = Join-Path $f ".claude\harness\telemetry.jsonl"
    Test-Path $telemetryPath | Should -BeTrue
    $lastEvent = Get-Content $telemetryPath | Select-Object -Last 1 | ConvertFrom-Json
    $lastEvent.event | Should -Be "fail-open-escape"
  }

  # F1: quoted-command preservation
  It "quoted command args preserved - exit 2 and output matches 'a b'" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":0}' `
      -ConfigJson '{"commands":{"testQuick":"Write-Output \"a b\"; exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "a b"
  }

  # F2: CJK round-trip in red/BOOM test
  It "CJK text appears in block message" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":0}' `
      -ConfigJson '{"commands":{"testQuick":"Write-Output BOOM; exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "驗證指令失敗"
  }

  # F3: stdin path (production path) - payload via actual stdin redirect
  It "stdin path: payload via piped stdin triggers block" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":0}' `
      -ConfigJson '{"commands":{"testQuick":"exit 1"}}'
    $payloadFile = Join-Path $env:TEMP ("oh-stop-stdin-" + [guid]::NewGuid() + ".json")
    $json = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    [IO.File]::WriteAllText($payloadFile, $json, (New-Object System.Text.UTF8Encoding $false))
    try {
      $result = cmd /c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$($script:gate)"" < ""$payloadFile"" 2>&1"
      $exitCode = $LASTEXITCODE
    } finally {
      Remove-Item $payloadFile -Force -ErrorAction SilentlyContinue
    }
    $exitCode | Should -Be 2
  }

  # F4a: stop_block_count=2 + stop_hook_active=false + red cmd → exit 2 (still blocks)
  It "valve boundary: block_count=2 stop_hook_active=false still blocks (exit 2)" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":2}' `
      -ConfigJson '{"commands":{"testQuick":"exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":false}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
  }

  # F4b: stop_block_count=1 + stop_hook_active=true + red cmd → exit 2 (still enforces, count<2)
  It "valve boundary: block_count=1 stop_hook_active=true still enforces (exit 2)" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"stop_block_count":1}' `
      -ConfigJson '{"commands":{"testQuick":"exit 1"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","stop_hook_active":true}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
  }
}
