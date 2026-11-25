# (liii pi app cli) 测试导览

`(liii pi app cli)` 是 Pi Coding Agent 的轻量命令行入口库，直接输出帮助，
并按需加载完整 CLI 实现以加速 `gf pi --help` 启动。

## 运行测试

```bash
gf test app/tests/liii/pi/app/cli/
```

## 测试文件索引

子库测试见各自子目录：

- `auth/` — `(liii pi app cli auth)` auth 子命令参数解析与密钥管理
- `help/` — `(liii pi app cli help)` 帮助文本定义与输出
- `impl/` — `(liii pi app cli impl)` 完整 CLI 分发与程序入口
- `tui/` — `(liii pi app cli tui)` TUI 启动信息提取
