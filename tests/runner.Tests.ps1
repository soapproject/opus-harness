BeforeAll {
  $script:runner = Join-Path $PSScriptRoot ".." "bench" "runner.ps1"
  $script:repo = Join-Path ([IO.Path]::GetTempPath()) ("oh-bench-repo-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Force $script:repo | Out-Null
  Push-Location $script:repo
  git init --quiet
  Set-Content seed.txt "seed" -Encoding utf8
  git add -A
  git -c user.email=t@t -c user.name=t commit -m seed --quiet
  $script:startCommit = (git rev-parse HEAD).Trim()
  Pop-Location

  $script:casesDir = Join-Path ([IO.Path]::GetTempPath()) ("oh-bench-cases-" + [guid]::NewGuid())
  $case = Join-Path $script:casesDir "case-01-stub"
  New-Item -ItemType Directory -Force $case | Out-Null
  @{ repo = $script:repo; startCommit = $script:startCommit; prompt = "create out.txt" } |
    ConvertTo-Json | Set-Content (Join-Path $case "case.json") -Encoding utf8
  Set-Content (Join-Path $case "verify.ps1") 'param([string]$Workdir) if (Test-Path (Join-Path $Workdir "out.txt")) { exit 0 } else { exit 1 }' -Encoding utf8

  $script:resultsDir = Join-Path ([IO.Path]::GetTempPath()) ("oh-bench-results-" + [guid]::NewGuid())

  # Create stub agent scripts to avoid inner-quote stripping when passed via -File
  $script:stubsDir = Join-Path ([IO.Path]::GetTempPath()) ("oh-bench-stubs-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Force $script:stubsDir | Out-Null
  Set-Content (Join-Path $script:stubsDir "agent-create.ps1") 'Set-Content out.txt done -Encoding utf8' -Encoding utf8
  Set-Content (Join-Path $script:stubsDir "agent-noop.ps1") 'exit 0' -Encoding utf8
}
AfterAll {
  # remove worktrees first so repo delete works
  if (Test-Path $script:repo) {
    Push-Location $script:repo
    git worktree prune 2>$null
    Pop-Location
  }
  Remove-Item -Recurse -Force $script:repo, $script:casesDir, $script:resultsDir, $script:stubsDir -ErrorAction SilentlyContinue
}

Describe "bench runner" {

  It "stub agent creates file - verify passes and runner exits 0" {
    $rd = Join-Path $script:resultsDir "t1"
    New-Item -ItemType Directory -Force $rd | Out-Null
    $stubPath = Join-Path $script:stubsDir "agent-create.ps1"
    $agentCmd = "pwsh -NoProfile -File $stubPath"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:runner `
      -CasesDir $script:casesDir `
      -ResultsDir $rd `
      -AgentCommand $agentCmd
    $ec = $LASTEXITCODE
    $ec | Should -Be 0
    $json = Get-ChildItem -LiteralPath $rd -Filter "*.json" | Sort-Object Name -Descending | Select-Object -First 1
    $json | Should -Not -BeNullOrEmpty
    $result = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
    $result.cases[0].case | Should -Be "case-01-stub"
    $result.cases[0].verifyExit | Should -Be 0
  }

  It "agent does nothing - runner still exits 0 and verifyExit is 1" {
    $rd = Join-Path $script:resultsDir "t2"
    New-Item -ItemType Directory -Force $rd | Out-Null
    $stubPath = Join-Path $script:stubsDir "agent-noop.ps1"
    $agentCmd = "pwsh -NoProfile -File $stubPath"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:runner `
      -CasesDir $script:casesDir `
      -ResultsDir $rd `
      -AgentCommand $agentCmd
    $ec = $LASTEXITCODE
    $ec | Should -Be 0
    $json = Get-ChildItem -LiteralPath $rd -Filter "*.json" | Sort-Object Name -Descending | Select-Object -First 1
    $json | Should -Not -BeNullOrEmpty
    $result = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
    $result.cases[0].verifyExit | Should -Be 1
  }

  It "case filter no-such-case - runner exits 0 and cases array is empty" {
    $rd = Join-Path $script:resultsDir "t3"
    New-Item -ItemType Directory -Force $rd | Out-Null
    $stubPath = Join-Path $script:stubsDir "agent-noop.ps1"
    $agentCmd = "pwsh -NoProfile -File $stubPath"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:runner `
      -CasesDir $script:casesDir `
      -ResultsDir $rd `
      -Case "no-such-case" `
      -AgentCommand $agentCmd
    $ec = $LASTEXITCODE
    $ec | Should -Be 0
    $json = Get-ChildItem -LiteralPath $rd -Filter "*.json" | Sort-Object Name -Descending | Select-Object -First 1
    $json | Should -Not -BeNullOrEmpty
    $result = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
    @($result.cases).Count | Should -Be 0
  }

  It "worktrees cleaned after run - no leftover case-01-stub-* dirs in bench/work" {
    $rd = Join-Path $script:resultsDir "t4"
    New-Item -ItemType Directory -Force $rd | Out-Null
    $stubPath = Join-Path $script:stubsDir "agent-create.ps1"
    $agentCmd = "pwsh -NoProfile -File $stubPath"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:runner `
      -CasesDir $script:casesDir `
      -ResultsDir $rd `
      -AgentCommand $agentCmd
    $ec = $LASTEXITCODE
    $ec | Should -Be 0
    # bench/work is under the runner script's dir (bench/)
    $workDir = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "bench") "work"
    $leftovers = Get-ChildItem -LiteralPath $workDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "case-01-stub-*" }
    @($leftovers).Count | Should -Be 0
  }
}