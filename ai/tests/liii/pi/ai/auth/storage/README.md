# (liii pi ai auth storage) 模块函数索引

`(liii pi ai auth storage)` 提供 auth.json 的读取与原子写原语（tmp 文件 + rename + chmod 0600），供 api_key 与 oauth 两条持久化路径共用。

使用时导入：

```scheme
(import (liii pi ai auth storage))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-auth-write-json!
```

## 函数分类索引

### 读取与路径
- `pi-auth-read-json` - 读取 auth.json 并解析为关联表
- `pi-auth-dir-path` - 解析配置目录（显式传入优先，缺省 ~/.gf/agent）

### 写入与替换
- `pi-auth-replace-entry` - 替换或追加某 provider 的 auth.json 条目
- `pi-auth-write-json!` - 原子写 auth.json（tmp + rename + chmod 0600）

### 规范化
- `pi-auth-normalize-provider` - 规范化 provider id（非空字符串）
- `pi-auth-normalize-secret` - 规范化 secret（非空 trim 后字符串）
