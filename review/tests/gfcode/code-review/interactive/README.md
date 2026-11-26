# (gfcode code-review interactive) 模块函数分类索引

`(gfcode code-review interactive)` 提供交互式 `/review` 命令的参数转换与 worker 会话请求构造。

使用时导入：

```scheme
(import (gfcode code-review interactive))
```

## 查看函数文档

```bash
gf doc pi-code-review-command
```

## 函数分类索引

### 交互命令
- `pi-code-review-command` - 将 `/review` 参数转换为通用 worker 可执行的只读审查请求；
  结构化审查失败时经 ctx 的 `fallback-runner` 请求一次只读降级重试
