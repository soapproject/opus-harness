BeforeAll {
  $script:gate = "$PSScriptRoot\..\hooks\gate-ratchet.ps1"
  function New-Fixture {
    param([string]$StateJson, [string]$ConfigJson, [string]$Root)
    if (-not $Root) { $Root = Join-Path $env:TEMP ("oh-ratchet-" + [guid]::NewGuid()) }
    $h = Join-Path $Root ".claude" "harness"
    New-Item -ItemType Directory -Force $h | Out-Null
    if ($StateJson) { Set-Content -LiteralPath (Join-Path $h "state.json") -Value $StateJson -Encoding utf8 }
    if ($ConfigJson) { Set-Content -LiteralPath (Join-Path $h "config.json") -Value $ConfigJson -Encoding utf8 }
    return $Root
  }
  function Invoke-Gate {
    param([string]$Fixture, [string]$PayloadJson)
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:gate -StdinJson $PayloadJson 2>&1
    return @{ Code = $LASTEXITCODE; Text = ($out | Out-String) }
  }
}

AfterAll {
  Get-ChildItem $env:TEMP -Filter "oh-ratchet-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  Get-ChildItem $env:TEMP -Filter "oh-rat-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  Get-ChildItem ([IO.Path]::GetTempPath()) -Filter "oh-t4b*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $docsRoot = Join-Path $env:TEMP "oh-rat-docs"
  if (Test-Path $docsRoot) { Remove-Item $docsRoot -Recurse -Force -ErrorAction SilentlyContinue }
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
    $r.Text | Should -Match "鎖定"
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

  # F6: CJK assertion in block test
  It "block message contains CJK 鎖定" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "鎖定"
  }

  # F7: notebook_path target with red=2 → exit 2
  It "notebook_path target with red=2 exits 2" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"NotebookEdit","tool_input":{"notebook_path":"' + ($f -replace '\\','\\') + '\\notebooks\\analysis.ipynb"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
  }

  # F8: default limit - config no voting, red=2 → exit 2
  It "default limit 2: no voting config, red=2 exits 2" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
  }

  # F9: harness-edit-allowed audit event
  It "harness-edit-allowed audit: red=2 edit harness file → exit 0 and telemetry event=harness-edit-allowed" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $harnessFile = ($f -replace '\\','\\') + '\\.claude\\harness\\state.json'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + $harnessFile + '"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 0
    $telemetryPath = Join-Path $f ".claude\harness\telemetry.jsonl"
    Test-Path $telemetryPath | Should -BeTrue
    $lastEvent = Get-Content $telemetryPath | Select-Object -Last 1 | ConvertFrom-Json
    $lastEvent.event | Should -Be "harness-edit-allowed"
  }

  # F10: anchoring - fixture with \docs\ in ancestor path, edit src → exit 2 (old unanchored would allow)
  It "anchoring: docs in ancestor path does not bypass ratchet for src edit" {
    $docsRoot = Join-Path $env:TEMP "oh-rat-docs"
    $projRoot = Join-Path $docsRoot "docs\proj"
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}' `
      -Root $projRoot
    $srcFile = Join-Path $f "src\a.ts"
    New-Item -ItemType Directory -Force (Split-Path $srcFile) | Out-Null
    Set-Content $srcFile "// stub" -Encoding utf8
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
  }

  # F11: no last_green_commit variant
  It "no last_green_commit: red=2 edit src → exit 2 and message matches 尚無綠點" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S3"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $payload = '{"cwd":"' + ($f -replace '\\','\\') + '","tool_name":"Edit","tool_input":{"file_path":"' + ($f -replace '\\','\\') + '\\src\\a.ts"}}'
    $r = Invoke-Gate -Fixture $f -PayloadJson $payload
    $r.Code | Should -Be 2
    $r.Text | Should -Match "尚無綠點"
  }

  # T4 (S5): platform-neutral payload paths - forward-slash file_path must normalize on any OS
  It "forward-slash payload paths: src target blocks and docs target is allowed" {
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S5","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}'
    $rootFwd = $f -replace '\\', '/'
    $srcPayload = '{"cwd":"' + $rootFwd + '","tool_name":"Edit","tool_input":{"file_path":"' + $rootFwd + '/src/a.ts"}}'
    $docsPayload = '{"cwd":"' + $rootFwd + '","tool_name":"Edit","tool_input":{"file_path":"' + $rootFwd + '/docs/p.md"}}'
    $rSrc = Invoke-Gate -Fixture $f -PayloadJson $srcPayload
    $rDocs = Invoke-Gate -Fixture $f -PayloadJson $docsPayload
    $rSrc.Code | Should -Be 2
    $rDocs.Code | Should -Be 0
  }

  # T4b (S5): root dir containing [ ] wildcard chars must not corrupt the allowlist match
  It "bracket chars in root: docs target is allowed and src target blocks" {
    $bracketRoot = Join-Path ([IO.Path]::GetTempPath()) ("oh-t4b[1]-" + [guid]::NewGuid())
    $f = New-Fixture `
      -StateJson '{"phase":"executing","suspended":false,"red_count":2,"active_slice":"S5","last_green_commit":"abc1234"}' `
      -ConfigJson '{"commands":{"test":"exit 0"},"voting":{"ratchetLimit":2}}' `
      -Root $bracketRoot
    $rootFwd = $f -replace '\\', '/'
    $docsPayload = '{"cwd":"' + $rootFwd + '","tool_name":"Edit","tool_input":{"file_path":"' + $rootFwd + '/docs/p.md"}}'
    $srcPayload = '{"cwd":"' + $rootFwd + '","tool_name":"Edit","tool_input":{"file_path":"' + $rootFwd + '/src/a.ts"}}'
    $rDocs = Invoke-Gate -Fixture $f -PayloadJson $docsPayload
    $rSrc = Invoke-Gate -Fixture $f -PayloadJson $srcPayload
    $rDocs.Code | Should -Be 0
    $rSrc.Code | Should -Be 2
  }
}
