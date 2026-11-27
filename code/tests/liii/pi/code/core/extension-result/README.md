# (liii pi code core extension-result) 模块函数索引

扩展命令执行结果的统一 record 类型。导入：

```scheme
(import (liii pi code core extension-result))
```

## 函数分类索引

- `make-review-error` / `review-error?` / `review-error-message` — 错误结果
- `make-review-no-files` / `review-no-files?` / `review-no-files-message` / `review-no-files-notice` — 无文件
- `make-review-ok` / `review-ok?` / `review-ok-report` — 成功报告
- `make-review-retry` / `review-retry?` / `review-retry-prompt` / `review-retry-on-finish` — 降级重试
- `make-review-session-request` / `review-session-request?` 及字段访问器 — 会话请求
- `review-result?` / `review-result-status` — 统一谓词与 tag
