# (liii pi code config oauth-hook) 测试导览

`(liii pi code config oauth-hook)` 构造并同步 oauth 401 强制刷新钩子：
`resolve-pi-config` 初始注入、会话内切模（含同 provider）与 `/login` 后
reload 都经 `pi-sync-oauth-refresh-hook` 按当前 provider 重同步，
保证请求层收到 401 时能强制 refresh 重试一次。

## 运行测试

```bash
bin/gf test code/tests/liii/pi/code/config/oauth-hook/
```

## 测试文件索引

- `pi-sync-oauth-refresh-hook-test.scm` — 有/无 oauth 凭据的注入与清除、
  会话中途 `/login` 后重同步、alist cfg 与缺省 env 支持
- `pi-make-refresh-oauth-hook-test.scm` — 钩子端到端：stub OAuth 服务
  refresh 成功落盘返回新 access；invalid_grant 清除凭据返回 #f；
  非 oauth provider 返回 #f
