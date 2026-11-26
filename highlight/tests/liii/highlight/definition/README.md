# (liii highlight definition) 模块函数分类索引

`(liii highlight definition)` 提供了语法定义模型及其解析加载能力。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/definition "函数名"
```

## 函数分类索引

### 一、上下文定义
- `make-context-def` - 创建上下文定义对象
- `context-def?` - 判断对象是否为上下文定义
- `context-def-name` - 获取上下文定义的名称
- `context-def-attribute` - 获取上下文默认应用属性
- `context-def-line-end-context` - 获取行尾跳转目标上下文
- `context-def-fallthrough-context` - 获取未匹配时跳转目标上下文
- `context-def-rules` - 获取上下文规则列表

### 二、语法定义
- `make-definition` - 创建语法定义对象
- `definition?` - 判断对象是否为语法定义
- `definition-name` - 获取语法定义的语言名称
- `definition-extensions` - 获取语法定义匹配的文件后缀列表
- `definition-contexts` - 获取所有上下文定义列表
- `definition-item-datas` - 获取所有 itemData 映射表
- `definition-initial-context-name` - 获取初始上下文名称
- `definition-find-context` - 按名称查找上下文定义
- `definition-item-data-def-style` - 查找 itemData 的默认样式名

### 三、定义加载与解析
- `parse-definition-json` - 从 JSON 对象解析整套语法定义
- `load-syntax-definition` - 根据语言名称从 highlight/resources/syntax/*.json 文件加载语法定义
- `load-definition-for-file` - 根据文件名自动查找并加载匹配的语法定义
