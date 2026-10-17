
# ============================================================
# QueryForge - Day 71
# Git Cleanup and Security Review
# Safe / Non-destructive
# ============================================================

$ErrorActionPreference = "Stop"

Set-Location "D:\QueryForge"

Write-Host "===== DAY 71 REPOSITORY REVIEW ====="

# ------------------------------------------------------------
# 1. Check repository and branch
# ------------------------------------------------------------

$root = git rev-parse --show-toplevel

if ($LASTEXITCODE -ne 0) {
    throw "Not a Git repository"
}

$branch = git branch --show-current

if ($branch -ne "main") {
    throw "Expected main branch; found $branch"
}

Write-Host "Repository: $root"
Write-Host "Branch: $branch"

# ------------------------------------------------------------
# 2. Protect existing staged files
# ------------------------------------------------------------

$stagedBefore = @(
    git diff --cached --name-only
)

if ($stagedBefore.Count -gt 0) {
    throw "Existing staged changes found. Review first."
}

# Check existing .gitignore changes

git diff --quiet -- .gitignore

if ($LASTEXITCODE -ne 0) {
    throw "Existing .gitignore changes need review"
}

git diff --cached --quiet -- .gitignore

if ($LASTEXITCODE -ne 0) {
    throw "Staged .gitignore changes need review"
}

# ------------------------------------------------------------
# 3. Inventory known pending files
# ------------------------------------------------------------

Write-Host "===== PENDING FILE REVIEW ====="

$pending = @(
    "docs/day65_etl_monitoring.md",
    "sql/practice/day60_final_healthcheck.sql",
    "docs/day57_backup_restore.md",
    "sql/practice/day63_performance_audit.sql"
)

$statusRows = @()

foreach ($file in $pending) {

    $status = @(
        git status --short -- $file
    )

    if ($status.Count -eq 0) {
        $statusRows += "${file}: CLEAN"
    }
    else {
        $statusRows += "${file}: $($status -join ' ')"
    }

    Write-Host $statusRows[-1]
}

# ------------------------------------------------------------
# 4. Review backup metadata without opening data
# ------------------------------------------------------------

Write-Host "===== BACKUP SAFETY ====="

$backupCount = 0
$backupBytes = 0

if (Test-Path ".\backups") {

    $backupFiles = @(
        Get-ChildItem ".\backups" -Recurse -File
    )

    $backupCount = $backupFiles.Count

    foreach ($file in $backupFiles) {
        $backupBytes += $file.Length
    }
}

Write-Host "Backup file count: $backupCount"
Write-Host "Backup total bytes: $backupBytes"

# Never automatically commit backups.

# ------------------------------------------------------------
# 5. Check for sensitive tracked paths
# ------------------------------------------------------------

Write-Host "===== TRACKED SECRET FILE CHECK ====="

$trackedFiles = @(
    git ls-files
)

if ($LASTEXITCODE -ne 0) {
    throw "Cannot list tracked Git files"
}

$sensitiveTracked = @(
    $trackedFiles | Where-Object {
        (
            $_ -match '^backups/' -or
            $_ -match '(^|/)\.env(\.[^/]+)?$' -or
            $_ -match '\.(pem|p12|pfx|key)$'
        ) -and
        $_ -notmatch '(^|/)\.env\.example$'
    }
)

if ($sensitiveTracked.Count -gt 0) {

    Write-Host "Sensitive tracked paths detected:"

    $sensitiveTracked | ForEach-Object {
        Write-Host $_
    }

    throw "Sensitive tracked paths require manual review"
}

# ------------------------------------------------------------
# 6. Scan pending text files for likely credentials
# ------------------------------------------------------------

Write-Host "===== SECRET INDICATOR SCAN ====="

$patterns = @{
    "PRIVATE_KEY" = '-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----'
    "GITHUB_TOKEN" = '(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}'
    "AWS_ACCESS_KEY" = '\bAKIA[0-9A-Z]{16}\b'
    "DATABASE_URL_PASSWORD" = '(?i)(?:postgres(?:ql)?|mysql)://[^:\s/@]+:[^@\s/]+@'
}

$findings = @()

foreach ($file in $pending) {

    if (-not (Test-Path $file)) {
        continue
    }

    $item = Get-Item $file

    if ($item.Length -gt 2MB) {
        $findings += "${file}: file too large to scan"
        continue
    }

    $content = [System.IO.File]::ReadAllText(
        $item.FullName
    )

    foreach ($key in $patterns.Keys) {

        if ([regex]::IsMatch(
            $content,
            $patterns[$key]
        )) {
            $findings += "${file}: $key"
        }
    }
}

if ($findings.Count -gt 0) {

    Write-Host "Potential security findings:"

    $findings | ForEach-Object {
        Write-Host $_
    }

    throw "Security review required before commit"
}

Write-Host "No high-confidence secret indicators found."
Write-Host "Manual security review is still required."

# ------------------------------------------------------------
# 7. Protect backups and .env files with .gitignore
# ------------------------------------------------------------

Write-Host "===== PROTECT LOCAL FILES ====="

$ignoreFile = Join-Path $root ".gitignore"

$rules = @(
    "/backups/",
    "/.env",
    "/.env.*",
    "!/.env.example",
    "__pycache__/",
    ".pytest_cache/",
    "*.py[cod]",
    ".venv/"
)

$existing = ""

if (Test-Path $ignoreFile) {
    $existing = [System.IO.File]::ReadAllText(
        $ignoreFile
    )
}

$existingLines = @(
    $existing -split '\r?\n'
)

$missingRules = @(
    $rules | Where-Object {
        $existingLines -notcontains $_
    }
)

$ignoreChanged = $missingRules.Count -gt 0

if ($ignoreChanged) {

    $prefix = ""

    if (
        $existing.Length -gt 0 -and
        -not $existing.EndsWith("`n")
    ) {
        $prefix = "`n"
    }

    $additional = (
        $prefix +
        "`n# QueryForge local backups and secrets`n" +
        ($missingRules -join "`n") +
        "`n"
    )

    $utf8 = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::AppendAllText(
        $ignoreFile,
        $additional,
        $utf8
    )
}

# Verify backup ignore rule works

if (Test-Path ".\backups") {

    git check-ignore -q -- backups/

    if ($LASTEXITCODE -ne 0) {
        throw "Backup directory is not ignored"
    }
}

Write-Host "Local backup protection verified."

# ------------------------------------------------------------
# 8. Run existing regression tests
# ------------------------------------------------------------

Write-Host "===== EXISTING REGRESSION TESTS ====="

$days = @(
    58, 59, 61, 62, 63, 64, 65,
    66, 67, 68, 69, 70
)

$tests = @()

foreach ($day in $days) {

    $found = @(
        Get-ChildItem ".\sql\practice" -File |
        Where-Object {
            $_.Name -match "^test_day${day}_.*\.py$"
        }
    )

    if ($found.Count -eq 0) {
        throw "Missing Day $day test file"
    }

    $tests += $found.FullName
}

py -m pytest -q @tests

if ($LASTEXITCODE -ne 0) {
    throw "Regression tests failed"
}

# ------------------------------------------------------------
# 9. Generate repository review report
# ------------------------------------------------------------

Write-Host "===== GENERATE DAY 71 REPORT ====="

$report = "docs/day71_repository_review.md"

$now = (Get-Date).ToUniversalTime().ToString(
    "yyyy-MM-dd HH:mm:ss 'UTC'"
)

$lines = @(
    "# QueryForge Day 71 - Repository Review",
    "",
    "Generated: $now",
    "",
    "## Reviewed pending files",
    ""
)

foreach ($line in $statusRows) {
    $lines += "- $line"
}

$lines += @(
    "",
    "## Backup safety",
    "",
    "- Backup files detected: $backupCount",
    "- Total backup bytes: $backupBytes",
    "- Backup content was not opened.",
    "- Backups are excluded from Git.",
    "",
    "## Security",
    "",
    "- No high-confidence credential patterns found in the four reviewed text files.",
    "- No tracked sensitive paths matched the configured checks.",
    "- Automated scans cannot guarantee that files contain no secrets.",
    "",
    "## Tests",
    "",
    "- Existing Day 58-70 regression tests passed.",
    "",
    "## Remaining work",
    "",
    "- Review and classify the four pre-existing pending files.",
    "- Do not discard or commit them without approval.",
    "- Verify operational backup restore and real-source ETL separately.",
    "",
    "## Safety",
    "",
    "- No project source file was deleted.",
    "- Existing pending source files were not modified.",
    "- Backups were not committed."
)

$utf8 = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    (Join-Path $root $report),
    ($lines -join "`n") + "`n",
    $utf8
)

# ------------------------------------------------------------
# 10. Stage only Day 71 artifacts
# ------------------------------------------------------------

Write-Host "===== STAGE DAY 71 ONLY ====="

$expected = @(
    "scripts/day71_repository_review.ps1",
    "docs/day71_repository_review.md"
)

if ($ignoreChanged) {
    $expected += ".gitignore"
}

git add -- $expected

if ($LASTEXITCODE -ne 0) {
    throw "Git add failed"
}

$actual = @(
    git diff --cached --name-only
) | Sort-Object

$expected = @(
    $expected | Sort-Object
)

if (
    [string]::Join("|", $actual) -ne
    [string]::Join("|", $expected)
) {
    throw "Unexpected staged files - STOP"
}

# ------------------------------------------------------------
# 11. Verify formatting and commit
# ------------------------------------------------------------

Write-Host "===== GIT FORMATTING ====="

git diff --cached --check

if ($LASTEXITCODE -ne 0) {
    throw "Git formatting failed"
}

git diff --cached --stat

Write-Host "===== COMMIT DAY 71 ====="

git commit -m "Day 71: review repository and protect local backups"

if ($LASTEXITCODE -ne 0) {
    throw "Git commit failed"
}

# ------------------------------------------------------------
# 12. Push to GitHub
# ------------------------------------------------------------

Write-Host "===== PUSH TO GITHUB ====="

git push origin main

if ($LASTEXITCODE -ne 0) {
    throw "GitHub push failed"
}

# ------------------------------------------------------------
# 13. Final status
# ------------------------------------------------------------

Write-Host "===== FINAL GIT STATUS ====="

git status -sb
git log -3 --oneline

Write-Host "===== DAY 71 REVIEW PUSH COMPLETE ====="
Write-Host "Older pending files still need review."
