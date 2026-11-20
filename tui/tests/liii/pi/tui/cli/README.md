# (liii pi tui cli) 测试导览

`(liii pi tui cli)` 是 Pi Coding Agent 的命令行入口库，负责剥离命令前缀、
分发 install/config/auth 子命令，并以 `make-pi-app` 驱动交互式 TUI 与脚本模式。

## 运行测试

```bash
bin/gf test tools/pi/tests/liii/pi/tui/cli/
```

## 测试文件索引

- `main-test.scm` — `main`：程序入口（以 command-line 调用 run-pi 并退出）
- `read-all-stdin-test.scm` — `read-all-stdin`：读取并拼接标准输入全部内容
- `run-pi-test.scm` — `run-pi`：命令行入口分发与错误兜底
- `run-goldpi-test.scm` — `run-goldpi`：run-pi 的别名入口

子库测试见各自子目录：

- `auth/` — `(liii pi tui cli auth)` auth 子命令参数解析与密钥管理
- `help/` — `(liii pi tui cli help)` 帮助文本定义与输出
- `tui/` — `(liii pi tui cli tui)` TUI 启动信息提取
