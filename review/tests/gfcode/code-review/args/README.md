# (gfcode code-review args) 模块函数分类索引

`(gfcode code-review args)` 提供交互式 `/review` 命令参数解析。

## 查看函数文档

```bash
gf doc pi-parse-review-args
```

## 函数分类索引

### 命令参数
- `pi-parse-review-args` - 解析文件、`--staged` 和 `--ref`，返回带诊断字段的选项表

## 错误行为

未知 `--` 选项、缺少 `--ref` 值或空的 `--ref=` 不抛异常，而是在 `error` 字段返回诊断文本。
