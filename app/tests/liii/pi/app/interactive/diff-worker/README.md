# (liii pi app interactive diff-worker) 模块函数索引

本模块在独立的 go 会话中处理 TUI 展示任务。通过 `(import (liii pi app interactive diff-worker))` 接入。

- `%pi-display-worker`：消费有界快照，从内存计算单卡结果和本轮净变化，不读取磁盘。
- `%diff-job!` / `%diff-finish-turn`：处理单个任务，结算后尝试发送汇总。

测试覆盖净变化、无效输入、预算降级和延迟放行 worker 时的队列调度。

```bash
gf test app/tests/liii/pi/app/interactive/diff-worker
```
