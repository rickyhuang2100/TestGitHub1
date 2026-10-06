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

```
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
```

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

```
$Line = Read-Host ">"

if ([string]::IsNullOrWhiteSpace($Line)) {
    break
}

$TagLines += $Line
```

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
Write-Host "Release notes:"
Write-Host "----------------------------------------"
Write-Host $TagMessage
Write-Host "----------------------------------------"
Write-Host ""