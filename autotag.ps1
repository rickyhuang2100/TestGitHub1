param(
    [ValidateSet("patch", "minor", "major")]
    [string]$VersionType = "patch"
)

$ErrorActionPreference = "Stop"

try {
    # ==========================================
    # 1. 檢查 Git 環境
    # ==========================================
    Write-Host ""
    Write-Host "========================================"
    Write-Host " AutoTag Release Tool"
    Write-Host "========================================"

    $Branch = (git branch --show-current).Trim()

    if ($LASTEXITCODE -ne 0) {
        throw "無法取得目前的 Git 分支。"
    }

    if ($Branch -ne "main") {
        throw "目前分支是 '$Branch'，請切換到 main 分支後再執行。"
    }

    $RepoRoot = (git rev-parse --show-toplevel).Trim()

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
        throw "無法取得 Git 專案根目錄。"
    }

    Set-Location $RepoRoot

    # ==========================================
    # 2. 取得上一個 Tag
    # ==========================================
    $VersionOutput = @(git describe --tags --abbrev=0 2>$null)
    $HasPreviousTag = ($LASTEXITCODE -eq 0 -and $VersionOutput.Count -gt 0)

    if ($HasPreviousTag) {
        $Version = $VersionOutput[0].Trim()
    }
    else {
        $Version = "v0.0.0"
    }

    if ($Version -notmatch '^v?(\d+)\.(\d+)\.(\d+)$') {
        throw "上一個 Tag '$Version' 不符合 vX.X.X 版本格式。"
    }

    $Major = [int]$Matches[1]
    $Minor = [int]$Matches[2]
    $Patch = [int]$Matches[3]

    # ==========================================
    # 3. 自動增加版本號
    # ==========================================
    switch ($VersionType) {
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
    }

    $NewTag = "v{0}.{1}.{2}" -f $Major, $Minor, $Patch

    # 避免重複建立已存在的 Tag
    $ExistingTag = @(git tag --list $NewTag)

    if ($ExistingTag.Count -gt 0) {
        throw "Tag '$NewTag' 已經存在，請檢查版本號。"
    }

    Write-Host ""
    Write-Host "Repository : $RepoRoot"
    Write-Host "Branch     : $Branch"
    Write-Host "Previous   : $Version"
    Write-Host "New Tag    : $NewTag"
    Write-Host ""

    # ==========================================
    # 4. 輸入多行 Tag 描述
    #    空白 Enter 結束輸入
    # ==========================================
    Write-Host "請輸入本次 Release 的描述。"
    Write-Host "每行輸入一項內容，空白 Enter 結束。"
    Write-Host ""

    $TagLines = [System.Collections.Generic.List[string]]::new()

    while ($true) {
        $Line = Read-Host "描述第 $($TagLines.Count + 1) 行"

        if ([string]::IsNullOrWhiteSpace($Line)) {
            break
        }

        $TagLines.Add($Line)
    }

    if ($TagLines.Count -eq 0) {
        throw "Tag 描述不可為空，已取消 Release。"
    }

    # 完整 Tag 描述
    $TagMessage = $TagLines -join "`n"

    # Commit 第一行加上描述第一行
    $CommitMessage = "Release $NewTag - $($TagLines[0])"

    # 其他描述行接在 Commit 訊息後面
    if ($TagLines.Count -gt 1) {
        $RemainingLines = @($TagLines | Select-Object -Skip 1)
        $CommitMessage += "`n" + ($RemainingLines -join "`n")
    }

    Write-Host ""
    Write-Host "Commit message:"
    Write-Host $CommitMessage
    Write-Host ""

    # ==========================================
    # 5. 自動加入所有檔案並建立 Release Commit
    # ==========================================
    Write-Host "Adding all files..."

    git add -A

    if ($LASTEXITCODE -ne 0) {
        throw "git add -A 執行失敗。"
    }

    git commit --allow-empty -m $CommitMessage

    if ($LASTEXITCODE -ne 0) {
        throw "建立 Release Commit 失敗。"
    }

    $ReleaseCommit = (git rev-parse HEAD).Trim()

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ReleaseCommit)) {
        throw "無法取得 Release Commit。"
    }

    Write-Host ""
    Write-Host "Release Commit: $ReleaseCommit"

    # ==========================================
    # 6. 建立附有完整描述的 Annotated Tag
    # ==========================================
    Write-Host ""
    Write-Host "Creating tag $NewTag ..."

    git tag -a $NewTag $ReleaseCommit -m $TagMessage

    if ($LASTEXITCODE -ne 0) {
        throw "建立 Tag '$NewTag' 失敗。"
    }

    # ==========================================
    # 7. 驗證 main 和 Tag 指向相同 Commit
    # ==========================================
    $MainCommit = (git rev-parse main).Trim()
    $TagCommit = (git rev-parse "$NewTag^{commit}").Trim()

    if ($LASTEXITCODE -ne 0) {
        throw "無法驗證 main 與 Tag 的 Commit。"
    }

    if ($MainCommit -ne $TagCommit -or $MainCommit -ne $ReleaseCommit) {
        throw "驗證失敗：main、Tag 與 Release Commit 並未指向相同 Commit。"
    }

    Write-Host ""
    Write-Host "OK: main and tag point to the same commit."
    Write-Host "Commit: $ReleaseCommit"

    # ==========================================
    # 8. 比較前一個 Tag 和新 Tag
    #    只保留新增、修改的檔案
    #    不列出刪除的檔案
    # ==========================================
    Write-Host ""
    Write-Host "Exporting changed file paths..."

    if ($HasPreviousTag) {
        $DiffOutput = @(
            git diff --name-status --no-renames $Version $NewTag --
        )

        if ($LASTEXITCODE -ne 0) {
            throw "比較前一個 Tag 與新 Tag 失敗。"
        }
    }
    else {
        # 第一次建立 Tag，沒有前一個 Tag：
        # 將新 Tag 中所有追蹤中的檔案列為新增檔案
        $DiffOutput = @(
            git ls-tree -r --name-only $NewTag
        )

        if ($LASTEXITCODE -ne 0) {
            throw "無法取得新 Tag 的檔案清單。"
        }

        $DiffOutput = @(
            foreach ($Path in $DiffOutput) {
                "A`t$Path"
            }
        )
    }

    $FullPaths = @(
        foreach ($Item in $DiffOutput) {
            $Parts = $Item -split "`t", 2

            if ($Parts.Count -ne 2) {
                continue
            }

            $Status = $Parts[0]
            $RelativePath = $Parts[1]

            # A = 新增、M = 修改、T = 檔案類型變更
            # D = 刪除，不輸出
            if ($Status -in @("A", "M", "T")) {
                $FullPath = [System.IO.Path]::GetFullPath(
                    (Join-Path $RepoRoot $RelativePath)
                )

                $FullPath
            }
        }
    )

    # 去除重複路徑並排序
    $FullPaths = @($FullPaths | Sort-Object -Unique)

    # ==========================================
    # 9. 輸出到 Windows 桌面
    #    日期 + 三位數流水號
    #    不覆蓋既有檔案
    # ==========================================
    $DesktopPath = [Environment]::GetFolderPath("Desktop")

    if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
        throw "無法取得 Windows 桌面路徑。"
    }

    $DateString = Get-Date -Format "yyyyMMdd"
    $Serial = 1

    do {
        $FileName = "TagDiffFiles_{0}_{1:D3}.txt" -f $DateString, $Serial
        $OutputFile = Join-Path $DesktopPath $FileName
        $Serial++
    } while (Test-Path $OutputFile)

    # UTF-8 無 BOM
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllLines(
        $OutputFile,
        [string[]]$FullPaths,
        $Utf8NoBom
    )

    Write-Host ""
    Write-Host "========================================"
    Write-Host "File Export Completed"
    Write-Host "========================================"
    Write-Host "Previous Tag : $Version"
    Write-Host "New Tag      : $NewTag"
    Write-Host "File Count   : $($FullPaths.Count)"
    Write-Host "Output File  : $OutputFile"
    Write-Host ""

    # ==========================================
    # 10. 推送 main 和 Tag 到遠端
    # ==========================================
    Write-Host "Pushing main..."

    git push origin main

    if ($LASTEXITCODE -ne 0) {
        throw "推送 main 失敗。Release Commit 和 Tag 已在本機建立。"
    }

    Write-Host ""
    Write-Host "Pushing tag $NewTag ..."

    git push origin $NewTag

    if ($LASTEXITCODE -ne 0) {
        throw "推送 Tag '$NewTag' 失敗。main 可能已推送成功，請檢查遠端狀態。"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "Release Completed Successfully!"
    Write-Host "========================================"
    Write-Host "Tag         : $NewTag"
    Write-Host "Commit      : $ReleaseCommit"
    Write-Host "File List   : $OutputFile"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

