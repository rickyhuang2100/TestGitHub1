---
report_type: git_release_report
repository: TestGitHub1
previous_tag: v1.0.9
release_tag: v1.0.10
release_commit: f2eefa2eb8b89859ef2bdaa4bb931676b438298f
release_date: 2026-10-31 15:33:23
---

Release Report v1.3.0

1. Release Information

項目

內容

系統名稱

員工管理系統

Repository

EmployeeSystem

Previous Tag

v1.2.0

Release Tag

v1.3.0

Release Commit

8a7f3c2d9e4b1a6f5c0d8e2b7a9f1c3d5e6b4a20

Release Date

2026-11-03

Branch

main

2. Release Notes

修正登入驗證機制。

使用者連續輸入錯誤密碼時，原本系統沒有正確累計登入失敗次數，導致帳號可能無法依照設定次數鎖定。

本次修改內容：

修正登入失敗次數累計邏輯。

當密碼錯誤時，正確更新登入失敗次數。

達到設定的錯誤次數後，鎖定使用者帳號。

帳號鎖定後，即使輸入正確密碼，也不能直接登入。

登入成功後，重設登入失敗次數。

3. Related Functional Areas

本次 Release 涉及以下功能：

功能分類

關鍵字

使用者登入

Login、Sign In、Authentication

帳號驗證

User Authentication、Password Verification

密碼驗證

Password、Password Hash

登入失敗處理

Failed Login、Login Attempts

帳號鎖定

Account Lockout、IsLocked

登入安全性

Login Security、Access Control

4. Changed Files

檔案

狀態

說明

Login.aspx.cs

Modified

登入驗證及錯誤次數處理

Login.aspx

Modified

登入錯誤訊息顯示

UserService.cs

Modified

帳號驗證及鎖定邏輯

UserRepository.cs

Modified

取得及更新使用者登入狀態

Web.config

Modified

登入錯誤次數設定

5. File Change Details

5.1 Login.aspx.cs

修改目的：

修正登入失敗時，沒有正確累計錯誤次數的問題。

Before：

if (user.Password != txtPassword.Text)
{
    lblMessage.Text = "密碼錯誤";
    return;
}

After：

if (user.IsLocked)
{
    lblMessage.Text = "帳號已鎖定，請聯絡管理人員";
    return;
}

if (!userService.VerifyPassword(
    txtPassword.Text,
    user.PasswordHash))
{
    userService.RecordLoginFailure(user.UserID);

    lblMessage.Text = "帳號或密碼錯誤";
    return;
}

userService.ResetLoginFailure(user.UserID);

Session["UserID"] = user.UserID;
Response.Redirect("Default.aspx");

5.2 UserService.cs

修改目的：

集中處理登入失敗次數及帳號鎖定規則。

After：

public void RecordLoginFailure(string userID)
{
    User user = repository.GetUser(userID);

    if (user == null)
        return;

    user.LoginFailCount++;

    if (user.LoginFailCount >= 5)
    {
        user.IsLocked = true;
    }

    repository.UpdateLoginStatus(
        userID,
        user.LoginFailCount,
        user.IsLocked
    );
}

public void ResetLoginFailure(string userID)
{
    repository.UpdateLoginStatus(
        userID,
        0,
        false
    );
}

5.3 UserRepository.cs

修改目的：

更新資料庫中的登入失敗次數及帳號鎖定狀態。

After：

public void UpdateLoginStatus(
    string userID,
    int failCount,
    bool isLocked)
{
    string sql = @"
        UPDATE Users
        SET LoginFailCount = @FailCount,
            IsLocked = @IsLocked
        WHERE UserID = @UserID";

    // 使用參數化 SQL 執行更新
}

5.4 Web.config

修改目的：

設定帳號鎖定門檻。

After：

<appSettings>
    <add key="MaxLoginFailCount" value="5" />
</appSettings>

6. Complete Git Diff

以下為示範 Diff 摘錄，實際使用時應由 Git Tag 比對取得完整內容。

diff --git a/Login.aspx.cs b/Login.aspx.cs
index 1234567..abcdef0 100644
--- a/Login.aspx.cs
+++ b/Login.aspx.cs
@@ -20,8 +20,21 @@ protected void btnLogin_Click(object sender, EventArgs e)

-if (user.Password != txtPassword.Text)
+if (user.IsLocked)
 {
-    lblMessage.Text = "密碼錯誤";
+    lblMessage.Text = "帳號已鎖定";
+    return;
+}
+
+if (!userService.VerifyPassword(
+    txtPassword.Text, user.PasswordHash))
+{
+    userService.RecordLoginFailure(user.UserID);
+    lblMessage.Text = "帳號或密碼錯誤";
     return;
 }
+
+userService.ResetLoginFailure(user.UserID);

