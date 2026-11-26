# (liii pi app interactive tool-diff) 模块函数索引

本模块提供有预算限制的行级 diff，通过 `(import (liii pi app interactive tool-diff))` 在展示 worker 中使用。

- `%tool-diff`：统计增删行、生成可选的纯文本上下文块。预算超限时不估算统计。
- `%diff-lines` / `%diff-matrix`：规范化换行并计算最长公共子序列。
- `%diff-hunks` / `%diff-preview`：将变更分组成有界的上下文预览。

```bash
gf test app/tests/liii/pi/app/interactive/tool-diff
```
