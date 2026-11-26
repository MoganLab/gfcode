# (gfcode code-review flow) 模块函数分类索引

`(gfcode code-review flow)` 提供代码审查的 CLI 执行流程：收集变更、构造只读审查参数、驱动会话并结算报告，含单次 fallback 与终端/json/verbose 三种输出模式。

使用时导入：

```scheme
(import (gfcode code-review flow))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc run-code-review-flow
```

## 函数分类索引

### CLI 流程入口
- `run-code-review-flow` - 执行代码审查流程，支持终端展示、JSON 事件与 verbose 三种模式
