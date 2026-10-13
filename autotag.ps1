param(
    [string]$VersionType = "patch",

    [string]$BranchListPath = ""
)

Write-Host ""
Write-Host "========================================"
Write-Host "Git Auto Tag"
Write-Host "========================================"
Write-Host ""

# Check Git repository

$RepoRoot = git rev-parse --show-toplevel 2>$null

if (-not $RepoRoot) {
    Write-Host "ERROR: Not a Git repository."
    exit 1
}

$RepoRoot = $RepoRoot.Trim()

Write-Host "Repository: $RepoRoot"

# Check current branch

$CurrentBranch = git branch --show-current

if ($CurrentBranch -ne "main") {
    Write-Host "ERROR: Current branch is not main."
    Write-Host "Current branch: $CurrentBranch"
    exit 1
}

Write-Host "Current branch: main"

# Get latest version

$Version = git describe --tags --abbrev=0 2>$null

if (-not $Version) {
    $Version = "v0.0.0"
}

$Version = $Version.Trim()

Write-Host "Current version: $Version"

# Parse version

$VersionClean = $Version -replace '^v', ''
$VersionParts = $VersionClean.Split('.')

if ($VersionParts.Count -ne 3) {
    Write-Host "ERROR: Version format must be vX.X.X."
    exit 1
}

try {
    $Major = [int]$VersionParts[0]
    $Minor = [int]$VersionParts[1]
    $Patch = [int]$VersionParts[2]
}
catch {
    Write-Host "ERROR: Cannot parse version."
    exit 1
}

# Increase version

switch ($VersionType.ToLower()) {

    "major" {
        $Major++
        $Minor = 0
        $Patch = 0
    }

    "minor" {
        $Minor++
        $Patch = 0
    }

    "patch" {
        $Patch++
    }

    default {
        Write-Host "ERROR: VersionType must be major, minor or patch."
        Write-Host ""
        Write-Host "Usage:"
        Write-Host "  .\autotag.ps1"
        Write-Host "  .\autotag.ps1 patch"
        Write-Host "  .\autotag.ps1 minor"
        Write-Host "  .\autotag.ps1 major"
        exit 1
    }

}

$NewTag = "v$Major.$Minor.$Patch"

Write-Host "New version: $NewTag"

# Check whether tag already exists

$TagExists = git tag -l $NewTag

if ($TagExists) {
    Write-Host "ERROR: Tag $NewTag already exists."
    exit 1
}

# ========================================
# Merge branches from release-branches.txt
# ========================================

# Ask for the file path if not specified
if ([string]::IsNullOrWhiteSpace($BranchListPath)) {
    $BranchListPath = Read-Host "Enter the full path of release-branches.txt"
}

# Convert to absolute path
$BranchListPath = $BranchListPath.Trim().Trim('"')
$BranchListPath = [System.IO.Path]::GetFullPath($BranchListPath)

if (-not (Test-Path -LiteralPath $BranchListPath -PathType Leaf)) {
    Write-Host "ERROR: Branch list file not found:"
    Write-Host $BranchListPath
    exit 1
}

$BranchListFile = $BranchListPath

Write-Host "Branch list: $BranchListFile"

if (-not (Test-Path $BranchListFile)) {
    Write-Host "ERROR: release-branches.txt was not found."
    exit 1
}

$ReleaseBranches = @(
    Get-Content $BranchListFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" -and -not $_.StartsWith("#") } |
    Select-Object -Unique
)

if ($ReleaseBranches.Count -eq 0) {
    Write-Host "ERROR: No branches specified in release-branches.txt."
    exit 1
}

# Make sure the working tree is clean before merging
if ((git status --porcelain | Measure-Object -Line).Lines -gt 0) {
    Write-Host "ERROR: Working tree is not clean."
    Write-Host "Please commit or stash changes before merging."
    exit 1
}

# Update remote branch information
git fetch origin

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: git fetch failed."
    exit 1
}

# Verify every branch exists before merging anything
foreach ($Branch in $ReleaseBranches) {

    git show-ref --verify --quiet "refs/remotes/origin/$Branch"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Remote branch not found: origin/$Branch"
        exit 1
    }
}

# ========================================
# Pre-check all branches before merging
# ========================================
Write-Host ""
Write-Host "Pre-checking merge conflicts..."

foreach ($Branch in $ReleaseBranches) {

    $RemoteBranch = "origin/$Branch"

    # Skip branches already merged into main
    git merge-base --is-ancestor $RemoteBranch "main"
    $MergeCheck = $LASTEXITCODE

    if ($MergeCheck -eq 0) {
        Write-Host "Already merged: $Branch"
        continue
    }

    if ($MergeCheck -ne 1) {
        Write-Host "ERROR: Cannot check branch: $Branch"
        exit 1
    }

    # Check whether the branch can be merged without conflicts
    git merge-tree --write-tree main $RemoteBranch

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Merge conflict or merge check failed: $Branch"
        Write-Host "Release cancelled. No branches have been merged by this script."
        exit 1
    }

    Write-Host "OK: No merge conflict: $Branch"
}

Write-Host ""
Write-Host "OK: All selected branches passed the pre-check."

# Merge each selected branch
foreach ($Branch in $ReleaseBranches) {

    $RemoteBranch = "origin/$Branch"

    Write-Host ""
    Write-Host "Checking branch: $Branch"

    git merge-base --is-ancestor $RemoteBranch "main"
    $MergeCheck = $LASTEXITCODE

    if ($MergeCheck -eq 0) {
        Write-Host "Already merged: $Branch"
        continue
    }

    if ($MergeCheck -ne 1) {
        Write-Host "ERROR: Cannot check branch: $Branch"
        exit 1
    }

    Write-Host "Merging $RemoteBranch into main..."

    git merge --no-edit --no-ff $RemoteBranch

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Merge failed for $Branch."
        Write-Host "Resolve conflicts before continuing."
        Write-Host "Do not create a release tag yet."
        exit 1
    }

    Write-Host "Merged successfully: $Branch"
}

Write-Host ""
Write-Host "OK: All selected branches have been merged into main."

# Enter tag description

Write-Host ""
Write-Host "========================================"
Write-Host "Tag description"
Write-Host "========================================"
Write-Host ""
Write-Host "Enter tag description."
Write-Host "You can enter multiple lines."
Write-Host "Press Enter on an empty line to finish."
Write-Host ""

$TagLines = @()

while ($true) {

    $Line = Read-Host ">"

    if ([string]::IsNullOrWhiteSpace($Line)) {
        break
    }

    $TagLines += $Line

}

if ($TagLines.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: Tag description cannot be empty."
    exit 1
}

$TagMessage = $TagLines -join "`n"

# First line of tag description

$FirstLine = $TagLines[0]

Write-Host ""
Write-Host "Tag message:"
Write-Host "----------------------------------------"
Write-Host $TagMessage
Write-Host "----------------------------------------"

# Add all files

Write-Host ""
Write-Host "Adding all files..."

git add -A

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: git add failed."
    exit 1
}

# Create release commit message

$CommitMessage = "Release $NewTag - $FirstLine"

if ($TagLines.Count -gt 1) {
    $RemainingLines = $TagLines[1..($TagLines.Count - 1)] -join "`n"
    $CommitMessage = "$CommitMessage`n$RemainingLines"
}

# Create release commit

Write-Host ""
Write-Host "Creating release commit..."

git commit --allow-empty -m "$CommitMessage"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: git commit failed."
    exit 1
}

# Get release commit

$ReleaseCommit = git rev-parse HEAD
$ReleaseShort = git rev-parse --short HEAD

Write-Host ""
Write-Host "Release commit: $ReleaseShort"

# Create annotated tag

Write-Host ""
Write-Host "Creating tag: $NewTag"

git tag -a $NewTag $ReleaseCommit -m "$TagMessage"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: git tag failed."
    exit 1
}

# Verify main and tag

$MainCommit = git rev-parse main
$TagCommit = git rev-parse "$NewTag^{commit}"

Write-Host ""
Write-Host "Checking release..."
Write-Host "main: $MainCommit"
Write-Host "tag : $TagCommit"

if ($MainCommit -ne $TagCommit) {
    Write-Host ""
    Write-Host "ERROR: main and tag point to different commits."
    exit 1
}

Write-Host "OK: main and tag point to the same commit."

# ========================================
# Export changed file paths
# ========================================

Write-Host ""
Write-Host "========================================"
Write-Host "Export changed file paths"
Write-Host "========================================"

# Compare previous tag and new tag
#
# A = Added
# M = Modified
# D = Deleted (will NOT be exported)
#
# --no-renames:
# Rename will be treated as Delete + Add.
# Therefore the old path will not be exported,
# and the new path will be exported.

$DiffOutput = @(
    git diff --name-status --no-renames $Version $NewTag
)

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to compare tags."
    exit 1
}

# Convert relative paths to full paths
# Only export A and M files

$FullPaths = @(
    foreach ($Item in $DiffOutput) {

        $Parts = $Item -split "`t", 2

        if ($Parts.Count -ne 2) {
            continue
        }

        $Status = $Parts[0]
        $RelativePath = $Parts[1]

        if ($Status -eq "A" -or $Status -eq "M") {

            $FullPath = [System.IO.Path]::GetFullPath(
                (Join-Path $RepoRoot $RelativePath)
            )

            $FullPath
        }
    }
)

# Remove duplicate paths and sort

$FullPaths = @(
    $FullPaths | Sort-Object -Unique
)

# Get Windows Desktop path

$DesktopPath = [Environment]::GetFolderPath("Desktop")

if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
    Write-Host "ERROR: Cannot find Windows Desktop."
    exit 1
}

# ========================================
# Generate filename:
#
# TagDiffFiles_20261008_001.txt
# TagDiffFiles_20261008_002.txt
# TagDiffFiles_20261008_003.txt
#
# Do not overwrite existing files.
# ========================================

$DateString = Get-Date -Format "yyyyMMdd"

$Serial = 1

do {

    $FileName = "TagDiffFiles_{0}_{1:D3}.txt" -f $DateString, $Serial

    $OutputFile = Join-Path $DesktopPath $FileName

    $Serial++

}
while (Test-Path $OutputFile)

# Write UTF-8 without BOM

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines(
    $OutputFile,
    [string[]]$FullPaths,
    $Utf8NoBom
)

Write-Host ""
Write-Host "Previous tag : $Version"
Write-Host "New tag      : $NewTag"
Write-Host "File count   : $($FullPaths.Count)"
Write-Host "Output file  : $OutputFile"
Write-Host ""
Write-Host "Changed file list exported successfully."

# Push main

Write-Host ""
Write-Host "Pushing main..."

git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to push main."
    exit 1
}

# Push tag

Write-Host ""
Write-Host "Pushing tag: $NewTag"

git push origin $NewTag

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to push tag."
    exit 1
}

# Done

Write-Host ""
Write-Host "========================================"
Write-Host "Release completed."
Write-Host "========================================"
Write-Host ""
Write-Host "Version: $NewTag"
Write-Host "Commit : $ReleaseShort"
Write-Host "Branch : main"
Write-Host "Tag    : $NewTag"
Write-Host ""
Write-Host "Changed files:"
Write-Host "----------------------------------------"

if ($FullPaths.Count -eq 0) {
    Write-Host "(No added or modified files)"
}
else {
    foreach ($Path in $FullPaths) {
        Write-Host $Path
    }
}

Write-Host ""
Write-Host "File list:"
Write-Host $OutputFile
Write-Host ""
Write-Host "Release notes:"
Write-Host "----------------------------------------"
Write-Host $TagMessage
Write-Host "----------------------------------------"
Write-Host ""