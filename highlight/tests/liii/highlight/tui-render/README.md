# (liii highlight tui-render) 模块函数分类索引

`(liii highlight tui-render)` 提供了将语法高亮分词结果渲染为 ANSI 24 位真彩色终端转义字符串的能力。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/tui-render "函数名"
```

## 函数分类索引

### 一、ANSI 转义前缀构造
- `style->ansi-prefix` - 根据样式条目构造 24 位真彩色 ANSI 转义前缀

### 二、终端着色渲染
- `render-spans-to-ansi` - 将单行 spans 渲染为带 ANSI 颜色的字符串
- `highlight-line-to-ansi` - 单行语法高亮并直接渲染为 ANSI 字符串
- `highlight-text-to-ansi` - 整段多行文本高亮渲染为 ANSI 字符串
