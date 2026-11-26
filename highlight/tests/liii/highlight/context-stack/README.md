# (liii highlight context-stack) 模块函数分类索引

`(liii highlight context-stack)` 提供高亮上下文栈的切换与栈顶查询工具，操作纯上下文名栈与 IncludeRules 帧，不触及高亮状态机记录。从 `(liii highlight highlighter)` 拆出。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/context-stack "函数名"
```

## 函数分类索引

### 一、上下文切换
- `apply-context-switch` - 按切换指令操作栈（含 IncludeRules 帧）
- `apply-context-switch-simple` - 对纯上下文名栈应用切换
- `apply-context-switch-host` - 宿主规则命中时丢弃 IncludeRules 帧并切换

### 二、栈顶查询
- `%top-context` - 取栈顶上下文与对应定义（含 IncludeRules 帧）
- `%include-frame?` - 判断栈顶是否为 IncludeRules 帧
