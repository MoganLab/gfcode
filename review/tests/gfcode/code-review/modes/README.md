# (gfcode code-review modes) 模块函数分类索引

`(gfcode code-review modes)` 是兼容入口，重新导出 `request`、`response`、`flow` 子模块的公共函数，保持原有 import 路径与公开导出不变。

使用时导入：

```scheme
(import (gfcode code-review modes))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc run-code-review-flow
gf doc pi-prepare-code-review
gf doc pi-code-review-parsed
gf doc pi-code-review-config
gf doc pi-code-review-response
```

## 函数分类索引

### 兼容导出（实现已拆分至子模块）

- `run-code-review-flow` - 执行代码审查流程（实现于 `(gfcode code-review flow)`）
- `pi-prepare-code-review` - 收集变更并构建只读审查请求（实现于 `(gfcode code-review request)`）
- `pi-code-review-parsed` - 构造含默认审查系统提示词的参数（实现于 `(gfcode code-review request)`）
- `pi-code-review-config` - 构造限制 `write`、`edit` 目标路径的审查配置（实现于 `(gfcode code-review request)`）
- `pi-code-review-response` - 将 Agent 最终消息转换为审查报告或错误（实现于 `(gfcode code-review response)`）
