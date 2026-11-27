# (gfcode code-review request) 模块函数分类索引

`(gfcode code-review request)` 提供代码审查会话执行前的请求准备逻辑：收集变更文件、构造提示词和审查工具配置。

使用时导入：

```scheme
(import (gfcode code-review request))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-prepare-code-review
gf doc pi-code-review-parsed
gf doc pi-code-review-config
```

## 函数分类索引

### 请求准备

- `pi-prepare-code-review` - 收集变更并构建可复用的只读审查请求
- `pi-code-review-parsed` - 构造含默认审查系统提示词的参数
- `pi-code-review-config` - 保留已启用的内置工具，在执行层限制 `write`、`edit` 的目标路径。不支持可靠的符号链接解析时禁用这两个工具；Bash 不受文件系统隔离。
