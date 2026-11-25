# (gfcode ...) 内置扩展单元测试

`tests/gfcode/` 验证 `.gf/gfcode/` 内置扩展库统一导出 `extension` 工厂的加载与注册行为。

从仓库根目录运行：

```bash
gf test .gf/tests/gfcode
```

- `tps/extension-test.scm` - TPS 扩展：事件钩子、usage 累加、格式化输出与通知回退
- `code-review/extension-test.scm` - code-review 扩展：flags / commands / validator / flow / prompt injector 注册
- `simplify/extension-test.scm` - simplify 扩展：flags / commands / validator / flow 注册
- `web-search/extension-test.scm` - web-search 扩展：web_search 工具注册与默认启用
