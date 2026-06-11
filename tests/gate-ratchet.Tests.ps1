BeforeAll {
  $script:gate = "$PSScriptRoot\..\hooks\gate-ratchet.ps1"
  function New-Fixture {
    param([string]$StateJson, [string]$ConfigJson)
    $f = Join-Path $env:TEMP ("oh-ratchet-" + [guid]::NewGuid())
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

Describe "gate-ratchet" {
  It "red_count below limit exits 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":1,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "red_count at limit exits 2 with ratchet message and telemetry" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "ratchet"
    $r.Text | Should -Match "abc1234"
    $telemetryPath = Join-Path $f ".claude\harness\telemetry.jsonl"
    Test-Path $telemetryPath | Should -BeTrue
    $lastLine = Get-Content $telemetryPath | Select-Object -Last 1
    ($lastLine | ConvertFrom-Json).constraint | Should -Be "ratchet"
  }

  It "harness path is whitelisted exits 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\.claude\\harness\\state.json"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "docs path is whitelisted exits 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\docs\\plan.md"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "phase review with high red_count exits 0" {
    $f = New-Fixture `
      -StateJson '{"phase":"review","suspended":false,"red_count":9}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
  }

  It "no harness dir exits 0" {
    $tempCwd = $env:TEMP
    $payload = '{"cwd":"' + ($tempCwd -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($tempCwd -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $tempCwd -PayloadJson $payload
    $r.Code | Should -Be 0
  }
}
