# (liii pi app cli impl) 测试导览

`(liii pi app cli impl)` 是 Pi Coding Agent 命令行的延迟加载实现库，
承载 `run-pi` / `run-goldpi` / `read-all-stdin` / `main` 的真实逻辑。
外层 `(liii pi app cli)` 仅作为轻量导出口，按需 `eval` 进入本库以加速 `--help` 启动。

## 运行测试

```bash
gf test app/tests/liii/pi/app/cli/impl/
```

## 测试文件索引

- `run-pi-test.scm` — `run-pi`：剥离命令前缀、分发子命令、帮助回退与错误码
- `run-goldpi-test.scm` — `run-goldpi`：`run-pi` 的别名入口
- `read-all-stdin-test.scm` — `read-all-stdin`：从标准输入读取完整字符串
- `main-test.scm` — `main`：程序入口绑定存在性（`exit` 行为由 `run-pi` 覆盖）
