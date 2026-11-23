# (liii pi ai auth oauth kimi-coding-oauth) 模块函数索引

`(liii pi ai auth oauth kimi-coding-oauth)` 实现 Kimi Code OAuth2 设备码登录（设备授权、轮询换 token、刷新），翻译自上游 pi 的 `kimi-coding.ts`。

使用时导入：

```scheme
(import (liii pi ai auth oauth kimi-coding-oauth))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc kimi-oauth-login
```

## 函数分类索引

### 设备授权
- `kimi-device-authorize` - 发起设备授权请求
- `kimi-device-authorization-p` - 设备授权记录谓词
- `kimi-device-authorization-device-code` - 取 device_code
- `kimi-device-authorization-user-code` - 取 user_code
- `kimi-device-authorization-verification-uri` - 取验证 URL
- `kimi-device-authorization-verification-uri-complete` - 取含 user_code 的验证 URL
- `kimi-device-authorization-interval-seconds` - 取轮询间隔
- `kimi-device-authorization-expires-in-seconds` - 取过期秒数

### 轮询与刷新
- `kimi-poll-token` - 轮询 token 端点直到完成
- `kimi-refresh-token` - 用 refresh_token 刷新 access token
- `kimi-oauth-login` - 完整登录：设备授权 → notify → 轮询换 token
- `kimi-oauth->auth` - 凭据 → 请求头

### Host 与常量
- `kimi-oauth-host` - 解析 OAuth host（env 覆盖 > 默认国内 host）
- `KIMI_OAUTH_CLIENT_ID` - Kimi Code OAuth client id
- `KIMI_OAUTH_DEFAULT_HOST` - 默认国内 OAuth host
