# (liii pi app interactive worker-extension-command) 模块函数分类索引

`(liii pi app interactive worker-extension-command)` 提供 worker 的扩展命令执行：
解析注册表中的命令、执行只读会话、处理 fallback 降级重试，并把事件回投给 app。

## 查看函数文档

```bash
gf doc pi-tui-run-extension-command!
gf doc pi-worker-run-extension-command-job!
```

## 函数分类索引

### 扩展命令执行
- `pi-tui-run-extension-command!` - 调用命令 handler，执行只读会话并回传报告或错误事件
- `pi-worker-run-extension-command-job!` - worker 的 `extension_command` job 分发，从注册表解析命令并执行
