# (liii highlight theme) 模块函数分类索引

`(liii highlight theme)` 提供了高亮主题与样式条目模型、颜色转换以及 JSON 主题文件解析能力。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/theme "函数名"
```

## 函数分类索引

### 一、样式条目
- `make-style-entry` - 创建样式条目对象
- `style-entry?` - 判断对象是否为样式条目
- `style-entry-text-color` - 获取样式前景色 RGB 三元组
- `style-entry-bg-color` - 获取样式背景色 RGB 三元组
- `style-entry-bold?` - 获取粗体标志
- `style-entry-italic?` - 获取斜体标志
- `style-entry-underline?` - 获取下划线标志

### 二、主题模型
- `make-theme` - 创建高亮主题对象
- `theme?` - 判断对象是否为高亮主题
- `theme-name` - 获取主题名称
- `theme-revision` - 获取主题版本号
- `theme-text-style` - 按样式名获取对应的文本样式条目
- `theme-editor-color` - 按颜色项名获取对应的编辑器颜色 RGB 三元组

### 三、颜色工具与主题解析
- `hex->rgb` - 将 16 进制颜色字符串转为 RGB 三元列表
- `parse-theme-json` - 解析 KSyntaxHighlighting .theme JSON 对象
- `default-breeze-dark-theme` - 获取内置 Breeze Dark 主题对象
