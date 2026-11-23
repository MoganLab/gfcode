# (liii pi ai auth oauth store) 模块函数索引

`(liii pi ai auth oauth store)` 提供 OAuth 运行时凭据存储：与请求配置分离，按 provider 保存最新凭据。store 可随不可变配置副本共享；刷新只替换 store 中的凭据，不修改配置对象，也不写 auth.json。

使用时导入：

```scheme
(import (liii pi ai auth oauth store))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-oauth-store-ref
```

## 函数分类索引

### 创建与判定
- `pi-make-oauth-store` - 创建 store，可选初始凭据列表
- `pi-oauth-store?` - 判断值是否为 store（单元素 vector）

### 读取
- `pi-oauth-store-ref` - 按 provider 精确匹配 oauth 凭据

### 更新
- `pi-oauth-store-set!` - 替换同 provider 条目
- `pi-oauth-store-load!` - 用凭据列表整体重载（只保留 oauth）
- `pi-oauth-store-remove!` - 移除指定 provider 条目
- `pi-oauth-store-clear!` - 清空全部凭据
