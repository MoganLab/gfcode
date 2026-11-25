# (gfcode ...) 内置扩展单元测试

`tests/gfcode/` 验证 `.gf/gfcode/` 单文件内置扩展库导出 `extension` 工厂的加载与注册行为。
多文件扩展位于各 domain 的 `gfcode/<name>/index.scm`（如 `review/gfcode/code-review/`），
其单元测试随 domain 放在 `<domain>/tests/gfcode/<name>/index/`。

从仓库根目录运行：

```bash
gf test .gf/tests/gfcode
```

- `tps/extension-test.scm` - TPS 扩展：事件钩子、usage 累加、格式化输出与通知回退

多文件扩展测试：

```bash
gf test review/tests/gfcode
gf test simplify/tests/gfcode
gf test web-search/tests/gfcode
```
