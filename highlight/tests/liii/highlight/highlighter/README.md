# (liii highlight highlighter) 模块函数分类索引

`(liii highlight highlighter)` 提供了高亮引擎状态机核心与多行文本着色分词功能。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/highlighter "函数名"
```

## 函数分类索引

### 一、高亮状态模型
- `make-highlight-state` - 创建高亮引擎状态对象
- `highlight-state?` - 判断对象是否为高亮状态
- `highlight-state-stack` - 获取上下文状态栈列表
- `initial-highlight-state` - 获取语法定义的初始高亮状态

### 二、文本高亮处理
- `highlight-line` - 高亮单行文本并返回 spans 与下一行状态
- `highlight-text` - 高亮整段多行文本并返回各行 spans 序列
