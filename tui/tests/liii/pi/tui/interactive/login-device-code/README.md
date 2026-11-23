# (liii pi tui interactive login-device-code) 模块函数索引

`(liii pi tui interactive login-device-code)` 提供 OAuth 设备码登录的 TUI 组件，展示 user code 与验证 URL 并打开浏览器。

使用时导入：

```scheme
(import (liii pi tui interactive login-device-code))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc make-login-device-code
```

## 函数分类索引

### 构造与字段
- `make-login-device-code` - 构造设备码登录组件
- `login-device-code-p` - 组件谓词
- `login-device-code-user-code` - 取 user code
- `login-device-code-verification-uri` - 取验证 URL
- `login-device-code-cursor-position` - 取光标位置
- `login-device-code-cancelled-p` - 是否已取消

### 行为
- `login-device-code-open-browser!` - 打开验证 URL 的浏览器
