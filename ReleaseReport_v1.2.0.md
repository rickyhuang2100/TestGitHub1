---
report_type: git_release_report
repository: SystemA
previous_tag: v1.1.0
release_tag: v1.2.0
release_commit: a1b2c3d4e5f6789012345678901234567890abcd
release_date: 2026-11-01 12:00:00
---

# Release Report v1.2.0

## Release Notes

新增使用者登入密碼特殊字元處理。

修正使用者輸入包含單引號及其他特殊字元時，登入驗證可能失敗的問題。

本次同時調整登入驗證相關程式，改為使用參數化 SQL 查詢。

---

# Release Information

| 項目 | 內容 |
|---|---|
| Repository | SystemA |
| Previous Tag | `v1.1.0` |
| Release Tag | `v1.2.0` |
| Release Commit | `a1b2c3d4e5f6789012345678901234567890abcd` |
| Release Date | `2026-11-01 12:00:00` |
| Branch | `main` |

---

# Release Branches

以下為本次 Release 確認並合併到 `main` 的 Branch：

- `feature/LoginValidation`
- `feature/UserManagement`

---

# Commit History

## Commit 1

- **Commit ID：** `8f7e6d5c4b3a2910abcdef1234567890abcdef12`
- **Author：** Ricky
- **Date：** `2026-10-28 10:15:30`
- **Message：** 修正登入密碼特殊字元驗證問題

## Commit 2

- **Commit ID：** `7a6b5c4d3e2f109876543210abcdef1234567890`
- **Author：** Ricky
- **Date：** `2026-10-29 14:20:10`
- **Message：** 調整使用者登入驗證流程

## Release Commit

- **Commit ID：** `a1b2c3d4e5f6789012345678901234567890abcd`
- **Author：** Ricky
- **Date：** `2026-11-01 11:30:00`
- **Message：** Release v1.2.0 - 修正登入密碼特殊字元驗證問題

---

# Changed Files

## Modified

- `M	SystemA/Login/Login.aspx.cs`
- `M	SystemA/Login/LoginService.cs`
- `M	SystemA/Web.config`

## Added

- `A	SystemA/Login/LoginValidationHelper.cs`

## Deleted

- `D	SystemA/Login/OldLoginHelper.cs`

## Renamed

- `R100	SystemA/Login/LoginHelper.cs → SystemA/Login/LoginUtility.cs`

---

# File Change Details

---

## SystemA/Login/Login.aspx.cs

### Change Information

- **Change Type：** Modified
- **Full Path：** `C:\Ricky\SystemA\Login\Login.aspx.cs`

### Before Change

```csharp
protected void LoginButton_Click(object sender, EventArgs e)
{
    string password = txtPassword.Text;

    string sql =
        "SELECT * FROM Users WHERE Password='" +
        password +
        "'";

    SqlCommand command = new SqlCommand(sql, connection);

    SqlDataReader reader = command.ExecuteReader();

    if (reader.HasRows)
    {
        Response.Redirect("Default.aspx");
    }
}
```

### After Change

```csharp
protected void LoginButton_Click(object sender, EventArgs e)
{
    string password = txtPassword.Text;

    string sql =
        "SELECT * FROM Users WHERE Password=@Password";

    SqlCommand command = new SqlCommand(sql, connection);

    command.Parameters.AddWithValue(
        "@Password",
        password
    );

    SqlDataReader reader = command.ExecuteReader();

    if (reader.HasRows)
    {
        Response.Redirect("Default.aspx");
    }
}
```

---

## SystemA/Login/LoginService.cs

### Change Information

- **Change Type：** Modified
- **Full Path：** `C:\Ricky\SystemA\Login\LoginService.cs`

### Before Change

```csharp
public bool ValidatePassword(string password)
{
    return password.Length >= 6;
}
```

### After Change

```csharp
public bool ValidatePassword(string password)
{
    if (string.IsNullOrEmpty(password))
    {
        return false;
    }

    return password.Length >= 6;
}
```

---

## SystemA/Login/LoginValidationHelper.cs

### Change Information

- **Change Type：** Added
- **Full Path：** `C:\Ricky\SystemA\Login\LoginValidationHelper.cs`

### Before Change

新增檔案，Previous Tag `v1.1.0` 中不存在此檔案。

### After Change

```csharp
public static class LoginValidationHelper
{
    public static bool IsValidPassword(string password)
    {
        return !string.IsNullOrWhiteSpace(password);
    }
}
```

---

## SystemA/Login/OldLoginHelper.cs

### Change Information

- **Change Type：** Deleted
- **Full Path：** `C:\Ricky\SystemA\Login\OldLoginHelper.cs`

### Before Change

```csharp
public class OldLoginHelper
{
    public bool Check(string password)
    {
        return password != "";
    }
}
```

### After Change

此檔案已在 `v1.2.0` 中刪除。

---

## SystemA/Web.config

### Change Information

- **Change Type：** Modified
- **Full Path：** `C:\Ricky\SystemA\Web.config`

### Before Change

```xml
<appSettings>
    <add key="LoginValidationMode" value="Old" />
</appSettings>
```

### After Change

```xml
<appSettings>
    <add key="LoginValidationMode" value="Parameter" />
</appSettings>
```

---

# Complete Git Diff

Comparison:

```text
Previous Tag : v1.1.0
Release Tag  : v1.2.0
```

```diff
diff --git a/SystemA/Login/Login.aspx.cs b/SystemA/Login/Login.aspx.cs
index 6540d7d..bd23327 100644
--- a/SystemA/Login/Login.aspx.cs
+++ b/SystemA/Login/Login.aspx.cs
@@ -10,14 +10,17 @@ protected void LoginButton_Click(object sender, EventArgs e)
 {
     string password = txtPassword.Text;

-    string sql =
-        "SELECT * FROM Users WHERE Password='" +
-        password +
-        "'";
+    string sql =
+        "SELECT * FROM Users WHERE Password=@Password";

     SqlCommand command = new SqlCommand(sql, connection);

+    command.Parameters.AddWithValue(
+        "@Password",
+        password
+    );
+
     SqlDataReader reader = command.ExecuteReader();
 }
diff --git a/SystemA/Login/LoginValidationHelper.cs b/SystemA/Login/LoginValidationHelper.cs
new file mode 100644
index 0000000..065f01e
--- /dev/null
+++ b/SystemA/Login/LoginValidationHelper.cs
@@ -0,0 +1,8 @@
+public static class LoginValidationHelper
+{
+    public static bool IsValidPassword(string password)
+    {
+        return !string.IsNullOrWhiteSpace(password);
+    }
+}
diff --git a/SystemA/Login/OldLoginHelper.cs b/SystemA/Login/OldLoginHelper.cs
deleted file mode 100644
index abc1234..0000000
--- a/SystemA/Login/OldLoginHelper.cs
+++ /dev/null
@@ -1,8 +0,0 @@
-public class OldLoginHelper
-{
-    public bool Check(string password)
-    {
-        return password != "";
-    }
-}
```

---

# Git Evidence

## Release Tag

```text
Tag:
v1.2.0
```

## Tag Commit

```text
v1.2.0
        ↓
a1b2c3d4e5f6789012345678901234567890abcd
```

## main Commit

```text
main
        ↓
a1b2c3d4e5f6789012345678901234567890abcd
```

## Verification Result

```text
main Commit SHA:
a1b2c3d4e5f6789012345678901234567890abcd

Tag Commit SHA:
a1b2c3d4e5f6789012345678901234567890abcd

Result:
OK - main and v1.2.0 point to the same Release Commit.
```

---

# Release Range Evidence

本次 Release 的比較範圍：

```text
Previous Tag
v1.1.0
        ↓
Git Diff
        ↓
Release Tag
v1.2.0
```

實際 Git 比較：

```text
git diff v1.1.0 v1.2.0
```

本報告中的：

- Changed Files
- Before Change
- After Change
- Complete Git Diff

均以 `v1.1.0 → v1.2.0` 的 Git 版本差異為依據。

---

# Report Evidence Summary

| 項目 | 證據來源 |
|---|---|
| Release Tag | Git Tag |
| Release Commit | Git Commit SHA |
| Release Branches | 本次 Release 合併紀錄 |
| Commit History | Git Log |
| Changed Files | Git Diff |
| Before Change | Previous Tag 中的檔案內容 |
| After Change | Release Tag 中的檔案內容 |
| Complete Git Diff | `git diff PreviousTag NewTag` |
| Tag 與 Commit 對應 | Git Rev-Parse 驗證 |

---

> 本 Release Report 為 Git Release 完成後產生的版本修改紀錄。
>
> LLM Wiki 可以根據本文件進行歷史版本、程式修改及檔案異動的查詢與分析。
>
> 涉及實際程式碼修改證據時，應以本報告中的 Git Tag、Commit SHA 與 Complete Git Diff 為準。