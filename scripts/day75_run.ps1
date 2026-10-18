
$ErrorActionPreference = "Stop"

Set-Location "D:\QueryForge"

function Check-Result {
    param([string]$Step)

    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed. Exit code: $LASTEXITCODE"
    }
}

try {

    Write-Host "===== DAY 75 FINAL VERIFICATION ====="

    $report = "docs/day75_backup_restore.md"
    $program = "sql/practice/day75_backup_restore.py"
    $testFile = "sql/practice/test_day75_backup_restore.py"
    $sqlFile = "sql/practice/day75_restore_audit.sql"
    $runner = "scripts/day75_run.ps1"

    # STEP 1: Git safety

    Write-Host "===== GIT SAFETY ====="

    $branch = git branch --show-current
    Check-Result "Git branch"

    if ($branch.Trim() -ne "main") {
        throw "Not on main branch"
    }

    $staged = @(git diff --cached --name-only)
    Check-Result "Git staged-files check"

    if ($staged.Count -gt 0) {
        throw "Existing staged changes detected"
    }

    # STEP 2: Check existing files

    Write-Host "===== FILE VERIFICATION ====="

    $required = @(
        $report,
        $program,
        $testFile,
        $sqlFile,
        $runner
    )

    foreach ($file in $required) {

        if (-not (Test-Path $file)) {
            throw "Missing file: $file"
        }

        Write-Host "FOUND: $file"
    }

    # STEP 3: Verify previous successful restore report

    Write-Host "===== BACKUP REPORT VERIFICATION ====="

    $content = Get-Content -Raw -LiteralPath $report

    $checks = @(
        "Custom archive inspection: PASS",
        "Restored database table counts: PASS",
        "Partition and materialized view structure: PASS"
    )

    foreach ($check in $checks) {

        if (-not $content.Contains($check)) {
            throw "Report result missing: $check"
        }

        Write-Host "PASS: $check"
    }

    # STEP 4: Locate backup archive from saved report

    Write-Host "===== BACKUP ARCHIVE VERIFICATION ====="

    $archiveMatch = [regex]::Match(
        $content,
        '- Backup archive \(outside Git\): `([^`]+)`'
    )

    if (-not $archiveMatch.Success) {
        throw "Backup filename missing from report"
    }

    $archiveName = $archiveMatch.Groups[1].Value

    if (
        $archiveName -notmatch
        '^queryforge_day75_[0-9]{8}_[0-9]{6}_[0-9a-f]{8}\.backup$'
    ) {
        throw "Invalid backup archive filename"
    }

    $archivePath = Join-Path "backups" $archiveName

    if (-not (Test-Path $archivePath)) {
        throw "Backup archive missing: $archivePath"
    }

    Write-Host "FOUND: $archivePath"

    # STEP 5: Verify SHA-256 checksum

    Write-Host "===== SHA256 VERIFICATION ====="

    $hashMatch = [regex]::Match(
        $content,
        '- SHA-256: `([0-9a-f]{64})`'
    )

    if (-not $hashMatch.Success) {
        throw "Expected SHA256 missing from report"
    }

    $expectedHash = $hashMatch.Groups[1].Value

    $actualHash = (
        Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()

    if ($expectedHash -ne $actualHash) {
        throw "Backup SHA256 mismatch"
    }

    Write-Host "BACKUP SHA256: PASS"

    # STEP 6: Ensure backup is ignored by Git

    Write-Host "===== BACKUP GIT PROTECTION ====="

    git check-ignore -q -- $archivePath
    Check-Result "Backup Git-ignore protection"

    Write-Host "BACKUP EXCLUDED FROM GIT: PASS"

    # STEP 7: Python syntax verification

    Write-Host "===== PYTHON SYNTAX ====="

    py -m py_compile $program $testFile
    Check-Result "Python syntax"

    Write-Host "PYTHON SYNTAX: PASS"

    # STEP 8: Day 75 tests

    Write-Host "===== DAY 75 UNIT TESTS ====="

    py -m pytest -q $testFile
    Check-Result "Day 75 unit tests"

    Write-Host "DAY 75 TESTS: PASS"

    # STEP 9: Stage ONLY the corrected runner

    Write-Host "===== STAGE CORRECTED RUNNER ONLY ====="

    git add -- $runner
    Check-Result "Git add"

    $actual = @(git diff --cached --name-only)
    Check-Result "Git staged file verification"

    if (
        $actual.Count -ne 1 -or
        $actual[0] -ne $runner
    ) {
        throw "Unexpected staged files detected"
    }

    # STEP 10: Formatting validation

    Write-Host "===== GIT FORMATTING ====="

    git diff --cached --check
    Check-Result "Git formatting"

    git diff --cached --stat

    # STEP 11: Commit correction

    Write-Host "===== COMMIT RUNNER FIX ====="

    git commit -m "Day 75: fix PowerShell verification runner"
    Check-Result "Git commit"

    # STEP 12: Push to GitHub

    Write-Host "===== PUSH TO GITHUB ====="

    git push origin main
    Check-Result "Git push"

    # STEP 13: Final status

    Write-Host "===== FINAL STATUS ====="

    git status -sb
    Check-Result "Git status"

    git log -3 --oneline
    Check-Result "Git log"

    Write-Host "===== DAY 75 RUNNER FIX COMPLETE ====="

}
catch {

    Write-Host "===== DAY 75 VERIFICATION FAILED =====" `
        -ForegroundColor Red

    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}
