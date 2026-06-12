#Requires -Version 5.1
param(
    [string]$CasesDir,
    [string]$ResultsDir,
    [string[]]$Case,
    [string]$AgentCommand = 'claude -p "{PROMPT}" --permission-mode acceptEdits',
    [switch]$KeepWork
)

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$ErrorActionPreference = "Continue"

# Apply defaults that depend on $PSScriptRoot (cannot use complex expressions in param block in PS5.1)
if (-not $CasesDir)   { $CasesDir   = Join-Path $PSScriptRoot "cases" }
if (-not $ResultsDir) { $ResultsDir = Join-Path $PSScriptRoot "results" }

# Ensure results dir exists
if (-not (Test-Path -LiteralPath $ResultsDir)) {
    New-Item -ItemType Directory -Force -LiteralPath $ResultsDir | Out-Null
}

# Ensure work dir exists
$workBase = Join-Path $PSScriptRoot "work"
if (-not (Test-Path -LiteralPath $workBase)) {
    New-Item -ItemType Directory -Force -LiteralPath $workBase | Out-Null
}

$results = @()
$ts = [datetime]::UtcNow

# Enumerate case directories
if (-not (Test-Path -LiteralPath $CasesDir)) {
    $caseDirs = @()
} else {
    $caseDirs = @(Get-ChildItem -LiteralPath $CasesDir -Directory -ErrorAction SilentlyContinue)
}

# Apply case filter
if ($Case -and $Case.Count -gt 0) {
    $caseDirs = @($caseDirs | Where-Object { $Case -contains $_.Name })
}

foreach ($caseDir in $caseDirs) {
    $caseName = $caseDir.Name
    $caseJsonPath = Join-Path $caseDir.FullName "case.json"

    if (-not (Test-Path -LiteralPath $caseJsonPath)) {
        $results += [pscustomobject]@{
            case            = $caseName
            error           = "missing case.json"
            agentExit       = -1
            verifyExit      = -1
            seconds         = 0
            workdir         = ""
            agentOutputTail = ""
        }
        continue
    }

    $caseData = $null
    try {
        $caseData = Get-Content -LiteralPath $caseJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $results += [pscustomobject]@{
            case            = $caseName
            error           = "invalid case.json: $_"
            agentExit       = -1
            verifyExit      = -1
            seconds         = 0
            workdir         = ""
            agentOutputTail = ""
        }
        continue
    }

    $repo        = $caseData.repo
    $startCommit = $caseData.startCommit
    $prompt      = $caseData.prompt

    # Build worktree path: bench/work/<caseName>-<yyyyMMddHHmmss> under the runner's dir
    $tsStamp = $ts.ToString("yyyyMMddHHmmss")
    $workdir = Join-Path $workBase ($caseName + "-" + $tsStamp)

    # git worktree add - run from within the repo
    $wtAddScript = "Push-Location -LiteralPath '$repo'; git worktree add --detach '$workdir' '$startCommit' 2>&1; `$ex = `$LASTEXITCODE; Pop-Location; exit `$ex"
    & pwsh -NoProfile -ExecutionPolicy Bypass -Command $wtAddScript 2>&1 | Out-Null
    $wtExit = $LASTEXITCODE

    if ($wtExit -ne 0) {
        $results += [pscustomobject]@{
            case            = $caseName
            error           = "worktree add failed"
            agentExit       = -1
            verifyExit      = -1
            seconds         = 0
            workdir         = $workdir
            agentOutputTail = ""
        }
        continue
    }

    # Build agent command: replace {PROMPT} token (double-quotes in prompt -> single-quotes)
    $safePrompt = $prompt -replace '"', "'"
    $cmd = $AgentCommand.Replace("{PROMPT}", $safePrompt)

    # Run agent in the worktree with CWD = worktree (Push-Location/try/finally)
    $agentExit = -1
    $agentOutput = ""

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Push-Location -LiteralPath $workdir
    try {
        $agentOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | ForEach-Object { "$_" } | Out-String
        $agentExit = $LASTEXITCODE
    } catch {
        $agentOutput = "Runner error during agent execution: $_"
        $agentExit = -1
    } finally {
        Pop-Location
    }
    $sw.Stop()
    $seconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)

    # Compute tail (last 20 lines)
    $agentLines = @($agentOutput -split "`n")
    if ($agentLines.Count -gt 20) {
        $tailLines = $agentLines[($agentLines.Count - 20)..($agentLines.Count - 1)]
    } else {
        $tailLines = $agentLines
    }
    $agentOutputTail = ($tailLines -join "`n").Trim()

    # Run verify.ps1
    $verifyScript = Join-Path $caseDir.FullName "verify.ps1"
    $verifyExit = -2
    $verifyError = ""

    if (-not (Test-Path -LiteralPath $verifyScript)) {
        $verifyError = "missing verify.ps1"
    } else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyScript -Workdir $workdir 2>&1 | Out-Null
        $verifyExit = $LASTEXITCODE
    }

    # Build result object
    $resultObj = [pscustomobject]@{
        case            = $caseName
        agentExit       = $agentExit
        verifyExit      = $verifyExit
        seconds         = $seconds
        workdir         = $workdir
        agentOutputTail = $agentOutputTail
    }
    if ($verifyError) {
        $resultObj | Add-Member -NotePropertyName "error" -NotePropertyValue $verifyError
    }

    $results += $resultObj

    # Cleanup worktree unless -KeepWork
    if (-not $KeepWork) {
        $rmScript = "Push-Location -LiteralPath '$repo'; git worktree remove --force '$workdir' 2>&1; Pop-Location"
        & pwsh -NoProfile -ExecutionPolicy Bypass -Command $rmScript | Out-Null
    }
}

# Write results JSON
$tsFile = $ts.ToString("yyyyMMdd-HHmmss")
$outputPath = Join-Path $ResultsDir ($tsFile + ".json")

$output = [pscustomobject]@{
    ts           = $ts.ToString("o")
    agentCommand = $AgentCommand
    cases        = $results
}

$json = $output | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outputPath, $json, $utf8NoBom)

Write-Host $outputPath
exit 0