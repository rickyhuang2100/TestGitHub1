#!/bin/bash

# 1. 獲取最新的一個 Tag，如果沒有就預設 v0.0.0
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# 2. 將版本號切碎 (例如 v1.2.3 變成 1 2 3)
VERSION_CLEAN=${VERSION#v}
MAJOR=$(echo $VERSION_CLEAN | cut -d. -f1)
MINOR=$(echo $VERSION_CLEAN | cut -d. -f2)
PATCH=$(echo $VERSION_CLEAN | cut -d. -f3)

# 3. 根據參數決定升級哪一個版號 (預設升級 patch)
case "$1" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  *)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_TAG="v$MAJOR.$MINOR.$PATCH"
echo "即將從 $VERSION 升級至 $NEW_TAG"

# 4. 在本機建立 Tag
git tag -a "$NEW_TAG" -m "自動編號：發佈版本 $NEW_TAG"

# 5. 推送到遠端伺服器
git push origin "$NEW_TAG"
git push origin main # 順便推送當前程式碼

echo "成功發佈 $NEW_TAG 到遠端伺服器！"