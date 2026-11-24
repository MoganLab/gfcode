# (liii pi ai auth whitelist) 模块函数索引

`(liii pi ai auth whitelist)` 提供 models/providers.json 白名单的读、写、合并原语（对齐 pi Models 的 completeProviderAuthentication：登录后把 provider 合并进白名单，使 /model 与 --list-models 即时可见）。保持 ai 层纯净，仅用 ai 层 + 标准库原语实现，不反向 import code 层（避免循环依赖）。

使用时导入：

```scheme
(import (liii pi ai auth whitelist))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-auth-save-provider-whitelist!
```

## 函数分类索引

### 内置集合与合并
- `pi-auth-builtin-provider-ids` - 内置 provider id 全集（白名单回退基线，排除 all-in-one）
- `pi-auth-merge-provider-id` - 不重复追加 provider id 到白名单列表

### 读写原语
- `pi-auth-read-provider-whitelist` - 读取 models/providers.json 白名单（兼容顶层 providers.json）
- `pi-auth-write-provider-whitelist!` - 原子写 models/providers.json 白名单（tmp + rename）
- `pi-auth-save-provider-whitelist!` - 合并 provider 进白名单（读现状→追加→原子落盘，失败静默）
