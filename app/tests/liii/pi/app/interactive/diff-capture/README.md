# (liii pi app interactive diff-capture) 模块函数索引

本模块只在 TUI agent worker 中观察 `edit` / `write`。通过 `(import (liii pi app interactive diff-capture))` 接入；原工具结果不变。

- `%pi-make-diff-capture`：创建本轮快照状态。
- `%pi-diff-executor` / `%pi-diff-emit`：捕获有界快照，并按工具调用编号发送任务。
- `%pi-diff-finish!` / `%pi-with-turn-diff`：在任务结束后释放本轮观察状态，不等待计算结果。

```bash
gf test app/tests/liii/pi/app/interactive/diff-capture
```
