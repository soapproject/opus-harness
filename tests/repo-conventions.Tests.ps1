# Repo conventions enforced as tests (see CLAUDE.md house rules).
BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  $script:trackedPs1 = @(& git -C $script:repoRoot ls-files "*.ps1" 2>$null) | Where-Object { $_ }
}

Describe "repo-conventions" {
  It "every tracked .ps1 starts with a UTF-8 BOM" {
    $script:trackedPs1.Count | Should -BeGreaterThan 0
    $missing = @()
    foreach ($rel in $script:trackedPs1) {
      $full = Join-Path $script:repoRoot $rel
      $bytes = [IO.File]::ReadAllBytes($full)
      if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) { $missing += $rel }
    }
    $missing | Should -BeNullOrEmpty
  }

  It "no tracked .ps1 or hooks.json references the legacy engine" {
    $legacy = "power" + "shell"   # built dynamically so this file never matches its own pattern
    $pattern = "\b$legacy(\.exe)?\b"
    $hits = @(& git -C $script:repoRoot grep -nE $pattern -- "*.ps1" "hooks/hooks.json" 2>$null) | Where-Object { $_ }
    $hits | Should -BeNullOrEmpty
  }
}
