---
report_type: git_release_report
repository: SystemA
previous_tag: v2.2.5
release_tag: v2.3.0
release_commit: a1b2c3d4e5f6789012345678901234567890abcd
release_date: 2026-11-02 12:00:00
---
# Release Report v2.3.0

## Release Notes

修正訂單重複送出時，可能造成庫存被重複扣除的問題。

原本使用者在網路延遲或重複點擊送出按鈕時，系統可能建立多筆相同訂單。

本次調整訂單建立流程，加入訂單重複處理檢查，並將庫存扣除與訂單建立放在同一個資料庫交易中。

---

# Release Information

|項目|內容|
|---|---|
|Repository|OrderSystem|
|Previous Tag|`v2.2.5`|
|Release Tag|`v2.3.0`|
|Release Commit|`9f8e7d6c5b4a3210abcdef1234567890abcdef12`|
|Release Date|`2026-11-02 13:30:00`|
|Branch|`main`|

---

# Release Branches

以下為本次 Release 確認並合併到 `main` 的 Branch：

- `feature/OrderDuplicateCheck`
    
- `feature/InventoryTransaction`
    

---

# Commit History

## Commit 1

- **Commit ID：** `1234abcd5678efgh9012abcd3456efgh7890abcd`
    
- **Author：** EngineerA
    
- **Date：** `2026-10-30 10:20:15`
    
- **Message：** 增加訂單重複送出檢查
    

## Commit 2

- **Commit ID：** `abcd1234efgh56789012abcd3456efgh7890abcd`
    
- **Author：** EngineerB
    
- **Date：** `2026-10-31 15:45:30`
    
- **Message：** 調整庫存扣除交易處理
    

## Release Commit

- **Commit ID：** `9f8e7d6c5b4a3210abcdef1234567890abcdef12`
    
- **Author：** ChiefEngineer
    
- **Date：** `2026-11-02 12:50:00`
    
- **Message：** Release v2.3.0 - 修正訂單重複扣除庫存問題
    

---

# Changed Files

## Modified

- `M OrderSystem/Order/CreateOrder.aspx.cs`
    
- `M OrderSystem/Services/OrderService.cs`
    
- `M OrderSystem/Services/InventoryService.cs`
    

## Added

- `A OrderSystem/Services/OrderDuplicateChecker.cs`
    

## Deleted

無。

## Renamed

無。

---

# File Change Details

---

## OrderSystem/Order/CreateOrder.aspx.cs

### Change Information

- **Change Type：** Modified
    
- **Full Path：** `C:\Projects\OrderSystem\Order\CreateOrder.aspx.cs`
    

### Before Change

```csharp
protected void btnSubmit_Click(object sender, EventArgs e)
{
    OrderService service = new OrderService();

    service.CreateOrder(
        CurrentUserId,
        txtProductId.Text,
        txtQuantity.Text
    );

    Response.Redirect("OrderSuccess.aspx");
}
```

### After Change

```csharp
protected void btnSubmit_Click(object sender, EventArgs e)
{
    string requestId = Request.Form["RequestId"];

    OrderService service = new OrderService();

    bool success = service.CreateOrder(
        CurrentUserId,
        txtProductId.Text,
        txtQuantity.Text,
        requestId
    );

    if (success)
    {
        Response.Redirect("OrderSuccess.aspx");
    }
    else
    {
        lblMessage.Text = "此訂單已處理，請勿重複送出。";
    }
}
```

---

## OrderSystem/Services/OrderService.cs

### Change Information

- **Change Type：** Modified
    
- **Full Path：** `C:\Projects\OrderSystem\Services\OrderService.cs`
    

### Before Change

```csharp
public void CreateOrder(
    string userId,
    string productId,
    string quantity)
{
    SaveOrder(userId, productId, quantity);

    InventoryService inventoryService =
        new InventoryService();

    inventoryService.ReduceStock(
        productId,
        quantity
    );
}
```

### After Change

```csharp
public bool CreateOrder(
    string userId,
    string productId,
    string quantity,
    string requestId)
{
    OrderDuplicateChecker checker =
        new OrderDuplicateChecker();

    if (checker.Exists(requestId))
    {
        return false;
    }

    using (SqlConnection connection =
        new SqlConnection(ConnectionString))
    {
        connection.Open();

        SqlTransaction transaction =
            connection.BeginTransaction();

        try
        {
            SaveOrder(
                userId,
                productId,
                quantity,
                requestId,
                connection,
                transaction
            );

            InventoryService inventoryService =
                new InventoryService();

            inventoryService.ReduceStock(
                productId,
                quantity,
                connection,
                transaction
            );

            transaction.Commit();

            return true;
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }
}
```

---

## OrderSystem/Services/InventoryService.cs

### Change Information

- **Change Type：** Modified
    
- **Full Path：** `C:\Projects\OrderSystem\Services\InventoryService.cs`
    

### Before Change

```csharp
public void ReduceStock(
    string productId,
    string quantity)
{
    string sql =
        "UPDATE Products " +
        "SET Stock = Stock - @Quantity " +
        "WHERE ProductId = @ProductId";

    Execute(sql, productId, quantity);
}
```

### After Change

```csharp
public void ReduceStock(
    string productId,
    string quantity,
    SqlConnection connection,
    SqlTransaction transaction)
{
    string sql =
        "UPDATE Products " +
        "SET Stock = Stock - @Quantity " +
        "WHERE ProductId = @ProductId";

    SqlCommand command =
        new SqlCommand(sql, connection, transaction);

    command.Parameters.AddWithValue(
        "@ProductId",
        productId
    );

    command.Parameters.AddWithValue(
        "@Quantity",
        quantity
    );

    command.ExecuteNonQuery();
}
```

---

## OrderSystem/Services/OrderDuplicateChecker.cs

### Change Information

- **Change Type：** Added
    
- **Full Path：** `C:\Projects\OrderSystem\Services\OrderDuplicateChecker.cs`
    

### Before Change

新增檔案，Previous Tag `v2.2.5` 中不存在此檔案。

### After Change

```csharp
public class OrderDuplicateChecker
{
    public bool Exists(string requestId)
    {
        string sql =
            "SELECT COUNT(*) " +
            "FROM Orders " +
            "WHERE RequestId = @RequestId";

        object result = ExecuteScalar(
            sql,
            requestId
        );

        return Convert.ToInt32(result) > 0;
    }
}
```

---

# Complete Git Diff

Comparison:

```text
Previous Tag : v2.2.5
Release Tag  : v2.3.0
```

```diff
diff --git a/OrderSystem/Order/CreateOrder.aspx.cs b/OrderSystem/Order/CreateOrder.aspx.cs
index 1234567..abcdef0 100644
--- a/OrderSystem/Order/CreateOrder.aspx.cs
+++ b/OrderSystem/Order/CreateOrder.aspx.cs
@@ -1,11 +1,19 @@
 protected void btnSubmit_Click(object sender, EventArgs e)
 {
+    string requestId = Request.Form["RequestId"];
+
     OrderService service = new OrderService();

-    service.CreateOrder(
+    bool success = service.CreateOrder(
         CurrentUserId,
         txtProductId.Text,
-        txtQuantity.Text
+        txtQuantity.Text,
+        requestId
     );

-    Response.Redirect("OrderSuccess.aspx");
+    if (success)
+    {
+        Response.Redirect("OrderSuccess.aspx");
+    }
+    else
+    {
+        lblMessage.Text = "此訂單已處理，請勿重複送出。";
+    }
 }
diff --git a/OrderSystem/Services/OrderDuplicateChecker.cs b/OrderSystem/Services/OrderDuplicateChecker.cs
new file mode 100644
index 0000000..9876543
--- /dev/null
+++ b/OrderSystem/Services/OrderDuplicateChecker.cs
@@ -0,0 +1,20 @@
+public class OrderDuplicateChecker
+{
+    public bool Exists(string requestId)
+    {
+        string sql =
+            "SELECT COUNT(*) " +
+            "FROM Orders " +
+            "WHERE RequestId = @RequestId";
+
+        object result = ExecuteScalar(
+            sql,
+            requestId
+        );
+
+        return Convert.ToInt32(result) > 0;
+    }
+}
```

> 完整正式報告中，這裡會由 `git diff v2.2.5 v2.3.0` 自動產生並保存所有檔案的完整 Diff。

---

# Git Evidence

## Release Tag

```text
Tag:
v2.3.0
```

## Tag Commit

```text
v2.3.0
        ↓
9f8e7d6c5b4a3210abcdef1234567890abcdef12
```

## main Commit

```text
main
        ↓
9f8e7d6c5b4a3210abcdef1234567890abcdef12
```

## Verification Result

```text
main Commit SHA:
9f8e7d6c5b4a3210abcdef1234567890abcdef12

Tag Commit SHA:
9f8e7d6c5b4a3210abcdef1234567890abcdef12

Result:
OK - main and v2.3.0 point to the same Release Commit.
```

---

# Release Range Evidence

本次 Release 的比較範圍：

```text
Previous Tag
v2.2.5
        ↓
Git Diff
        ↓
Release Tag
v2.3.0
```

實際 Git 比較：

```text
git diff v2.2.5 v2.3.0
```

本報告中的：

- Changed Files
    
- Before Change
    
- After Change
    
- Complete Git Diff
    

均以 `v2.2.5 → v2.3.0` 的 Git 版本差異為依據。

---

# Report Evidence Summary

|項目|證據來源|
|---|---|
|Release Tag|Git Tag|
|Release Commit|Git Commit SHA|
|Release Branches|本次 Release 合併紀錄|
|Commit History|Git Log|
|Changed Files|Git Diff|
|Before Change|Previous Tag 中的檔案內容|
|After Change|Release Tag 中的檔案內容|
|Complete Git Diff|`git diff PreviousTag NewTag`|
|Tag 與 Commit 對應|Git Rev-Parse 驗證|

---