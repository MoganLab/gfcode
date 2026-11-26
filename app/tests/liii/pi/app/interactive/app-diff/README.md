# (liii pi app interactive app-diff) 模块函数索引

本模块管理 TUI 当前轮的 diff 展示状态。通过 `(import (liii pi app interactive app-diff))` 在应用层接入；它不读写会话文件。

- `%pi-app-handle-diff-event!`：关联运行编号和工具调用编号，记录早到结果。
- `%pi-app-apply-diff!`：工具完成后原地更新匹配的卡片。
- `%pi-app-settle-diff!` / `%pi-app-reset-diff!`：结算时展示汇总，或在新一轮派发时丢弃旧状态。

`app-diff-test.scm` 覆盖事件顺序和渲染，`diff-history-test.scm` 覆盖会话恢复隔离。

```bash
gf test app/tests/liii/pi/app/interactive/app-diff
```
