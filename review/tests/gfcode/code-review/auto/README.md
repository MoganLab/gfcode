# (gfcode code-review auto) 模块函数分类索引

`(gfcode code-review auto)` 提供工具调用自动审查注入功能，从 write/edit 工具调用中提取修改文件，并在下一轮对话前注入轻量代码自查要求。

使用时导入：

```scheme
(import (gfcode code-review auto))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-edited-files-from-tool-calls
gf doc pi-build-review-injection
gf doc make-pi-review-edit-tracker
gf doc pi-review-track-tool-result!
gf doc pi-review-tracker-end-turn!
gf doc pi-review-tracker-take-edits!
```

## 函数分类索引

### 自动审查注入
- `pi-edited-files-from-tool-calls` - 从工具调用列表中提取由 write 或 edit 修改的文件路径与语言信息
- `pi-build-review-injection` - 构建自动审查注入文本块
- `make-pi-review-edit-tracker` - 创建按 turn 聚合成功编辑的追踪器（ST4 实现）
- `pi-review-track-tool-result!` - 记录成功的 write/edit 执行结果（ST4 实现）
- `pi-review-tracker-end-turn!` - 将当前 turn 的编辑固化为快照（ST4 实现）
- `pi-review-tracker-take-edits!` - 消费并清空上一 turn 的快照（ST4 实现）
