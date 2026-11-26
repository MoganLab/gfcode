# (liii highlight code-block) 模块函数分类索引

`(liii highlight code-block)` 提供 Markdown 围栏代码块的纯解析工具与 IncludeRules 子定义缓存，不触及高亮状态机与上下文栈。从 `(liii highlight highlighter)` 拆出。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/code-block "函数名"
```

## 函数分类索引

### 一、围栏代码块识别
- `fenced-code-frame?` - 判断栈帧是否为围栏代码块帧
- `%parse-code-block-open` - 解析围栏代码块起始行
- `%code-block-close-line?` - 判断当前行是否为围栏代码块闭合行
- `%code-block-open-info` - 提取围栏代码块起始信息串

### 二、语言与子定义
- `%normalize-code-lang` - 归一化围栏代码块语言标识
- `%resolve-sub-definition` - 按语言名解析并缓存子语法定义
- `%extract-first-word` - 提取字符串首个空白分隔词
- `%rest-all-spaces?` - 判断从指定位置到行尾是否全为空格/Tab
