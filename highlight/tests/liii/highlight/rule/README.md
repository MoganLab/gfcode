# (liii highlight rule) 模块函数分类索引

`(liii highlight rule)` 提供了 Kate 兼容的语法高亮规则模型与匹配执行引擎。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/rule "函数名"
```

## 函数分类索引

### 一、规则模型
- `make-rule` - 创建匹配规则对象
- `rule?` - 判断对象是否为匹配规则
- `rule-type` - 获取规则类型
- `rule-attribute` - 获取规则匹配后赋予的样式属性
- `rule-context-target` - 获取规则匹配后的上下文跳转目标
- `rule-data` - 获取规则附属匹配数据
- `rule-look-ahead?` - 获取前瞻匹配标志
- `rule-first-non-space?` - 获取行首非空字符标志
- `rule-column` - 获取列限制

### 二、上下文跳转
- `parse-context-switch` - 解析上下文跳转指令为操作与目标名称

### 三、规则匹配
- `match-rule` - 对文本在指定偏移处执行单条规则匹配

> 匹配结果对象（`make-match-result`、`match-result?`、`match-result-matched?`、`match-result-new-offset`）由 `(liii highlight rule-matcher)` 提供，详见该模块导览。
