# (liii highlight structure) 模块函数分类索引

本模块定义 syntax JSON 的结构 Schema 与已校验的 Scheme 记录。它只描述结构，不读取输入、不执行高亮，也不控制输出速率。

## Schema 语义

- `line`：当前真实行尾闭合，适用于 Markdown 单行标题。
- `delimited`：独立开始和结束事件，适用于 fenced code。
- `nested`：可递归嵌套，适用于 Scheme list、JSON object/array 和 C++ 通用括号树。
- `emit-unclosed`：EOF 交付未闭合结构，保留原文并标记 `closed? = #f`。
- `error-and-emit`：EOF 先产生 `unexpected-eof` 错误事件，再交付未闭合结构。
- `unexpected-close`：结构栈为空时收到关闭事件。
- `mismatched-delimiter`：关闭事件与当前打开结构的结束事件不一致。

T01 只实现模型和校验；规则事件 JSON 解析在 T02，输入流和运行时结构栈在 T03。

## 查看函数文档

```bash
gf doc liii/highlight/structure "函数名"
```

## 函数分类索引

### 结构定义

- `make-structure-definition` - 构造并校验单行、定界或嵌套结构。
- `structure-definition?` - 判断结构定义对象。
- `structure-definition-name` - 获取语法内结构名称。
- `structure-definition-role` - 获取公开结构角色。
- `structure-definition-scope` - 获取 `line`、`delimited` 或 `nested`。
- `structure-definition-begin` - 获取开始事件。
- `structure-definition-end` - 获取结束事件。
- `structure-definition-metadata` - 获取静态元数据。
- `structure-definition-children` - 获取嵌套子结构名称。
- `structure-definition-include-begin?` - 查询是否包含开始标记。
- `structure-definition-include-end?` - 查询是否包含结束标记。
- `structure-definition-on-eof` - 获取 EOF 策略。

### 结构集合

- `make-structure-set` - 构造并校验结构集合。
- `structure-set?` - 判断结构集合对象。
- `structure-set-version` - 获取 Schema 版本。
- `structure-set-default` - 获取默认结构角色。
- `structure-set-root-scope` - 获取根消费视图。
- `structure-set-structures` - 获取结构定义列表。
