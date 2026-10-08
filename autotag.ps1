param(
[string]$VersionType = "patch"
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