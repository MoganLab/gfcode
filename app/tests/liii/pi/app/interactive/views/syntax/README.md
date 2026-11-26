# (liii pi app interactive views syntax) 模块函数索引

- `%worker-parser`：为当前展示 worker 创建 Diff 解析器，定义加载结果在多次请求间复用。
- `%make-diff-parser`：允许注入定义加载器和解析过程，便于验证失败降级和调用次数。
- `%diff-text-budget?`、`%merge-diff-spans`：分别检查清理后文本的预算、合并相邻同样式片段。

```bash
gf test app/tests/liii/pi/app/interactive/views/syntax
```
