param(
    [Parameter(Mandatory)]
    [string]$NewBaseBranch
)

$PrBranch        = 'branch3'
$OriginalBase    = 'main'
$TempBranch      = "${PrBranch}_clean"

git fetch origin

# 2) Compute changes first (so we can no-op cleanly)
$changed = git diff --name-only "origin/$OriginalBase...origin/$PrBranch"

$deleted = git diff --name-status "origin/$OriginalBase...origin/$PrBranch" |
    Where-Object { $_ -match '^D\s+' } |
    ForEach-Object { ($_ -split '\s+')[1] }

# Nothing to do? Exit without touching branches or pushing.
if ((-not $changed -or $changed.Count -eq 0) -and (-not $deleted -or $deleted.Count -eq 0)) {
    Write-Host "No changed or deleted files between $OriginalBase and $PrBranch. Doing nothing."
    exit 0
}

# 1) Start clean from new base
git checkout -B $TempBranch "origin/$NewBaseBranch"

# 3) Bring changed files' CONTENT from PR branch (only if any)
if ($changed -and $changed.Count -gt 0) {
    git checkout "origin/$PrBranch" -- $changed
}

# 4) Handle deletions (only if any)
if ($deleted -and $deleted.Count -gt 0) {
    git rm -f -- $deleted
}

# 5) Commit only if there is something staged
git add -A
$staged = git diff --cached --name-only
if (-not $staged -or $staged.Count -eq 0) {
    Write-Host "No staged changes after applying diff. Cleaning up and exiting without push."
    git checkout $NewBaseBranch
    git branch -D $TempBranch
    exit 0
}

git commit -m "Apply $PrBranch file changes onto $NewBaseBranch"
git push --force-with-lease origin "$TempBranch`:$PrBranch"

# 6) Cleanup
git checkout $NewBaseBranch
git branch -D $TempBranch
