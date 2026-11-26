# (gfcode code-review request) 模块函数分类索引

`(gfcode code-review request)` 提供代码审查会话执行前的请求准备逻辑：收集变更文件、构造禁止工具调用的审查参数与配置。

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
- `pi-code-review-parsed` - 构造禁止工具调用的审查参数
- `pi-code-review-config` - 构造工具列表为空的审查配置
