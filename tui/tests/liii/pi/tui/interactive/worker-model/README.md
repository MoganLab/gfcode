# (liii pi tui interactive worker-model) 模块函数索引

`(liii pi tui interactive worker-model)` 提供模型选择与请求前刷新逻辑：独立于 jobs-chan 的“最新请求选择”通道，在每次新 Provider 请求前解析最新选择并派生完整 effective-cfg。

使用时导入：

```scheme
(import (liii pi tui interactive worker-model))
```

## 函数分类索引

- `pi-worker-make-prepare-request` - 构造 prepare-request 过程（排空通道、latest-wins、派生并保存 effective-cfg）
- `pi-worker-apply-selection` - 把一条选择快照应用到 base-cfg，派生完整配置（跨 provider 执行 augment）
- `pi-worker-merge-model` - 覆盖模型相关项并按新 provider 重同步 oauth 401 刷新钩子（含同 provider 切模）
- `pi-make-effective-cfg-box` / `pi-effective-cfg-ref` / `pi-effective-cfg-set!` - runtime/effective-cfg 容器

详见当前目录下的单元测试用例。
