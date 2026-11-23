# (liii pi ai auth oauth resolve) 模块函数索引

`(liii pi ai auth oauth resolve)` 提供 OAuth 凭据的解析与透明刷新，供 `pi-resolve-provider-key` 的 oauth 分支与请求层 401 回退使用。

使用时导入：

```scheme
(import (liii pi ai auth oauth resolve))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-resolve-oauth-credential-key
```

## 函数分类索引

### 凭据查找
- `pi-find-oauth-credential` - 在凭据列表中按 provider 精确匹配 oauth 凭据
- `pi-has-oauth-credential?` - 探测凭据列表中是否存在某 provider 的 oauth 凭据

### 凭据解析与刷新
- `pi-resolve-oauth-credential-key` - oauth 凭据 → access token：未过期直接返回，过期透明刷新并落盘
- `pi-force-refresh-oauth-credential-key` - 强制刷新（不查 expires），供请求层收到 401 后回退使用
