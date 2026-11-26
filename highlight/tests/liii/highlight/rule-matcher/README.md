# (liii highlight rule-matcher) 模块函数分类索引

`(liii highlight rule-matcher)` 提供了规则的匹配执行内核：匹配结果记录、各类型规则的 `do-match` 实现，以及分隔符判定。从 `(liii highlight rule)` 拆出，使规则描述/分发与匹配实现分离，两者均控制在单文件行数上限内。

## 查看函数文档

使用以下命令查看函数文档和测试用例：
```bash
gf doc liii/highlight/rule-matcher "函数名"
```

## 函数分类索引

### 一、匹配结果模型
- `make-match-result` - 创建规则匹配结果对象
- `match-result?` - 判断对象是否为匹配结果
- `match-result-matched?` - 获取匹配是否成功标志
- `match-result-new-offset` - 获取匹配后新文本偏移

### 二、字符与文本匹配实现
- `%match-detect-char` - 检测单个字符
- `%match-detect-2chars` - 检测连续两个字符
- `%match-any-char` - 检测字符集合中的任一字符
- `%match-string-detect` - 检测固定字符串前缀
- `%match-word-detect` - 检测独立单词（带边界）
- `%match-keyword` - 检测关键字集合中的单词
- `%match-int` - 检测十进制整数
- `%match-detect-spaces` - 检测连续空格/Tab
- `%match-detect-identifier` - 检测标识符
- `%match-charset-run` - 字符集连续扫描
- `%match-hex` - 检测十六进制字面量
- `%match-json-number` - 检测 JSON 整数/浮点数
- `%match-json-exponent` - 处理 JSON 数值的指数后缀
- `%match-json-number-suffix` - 处理 JSON 数值的小数/指数后缀
- `%match-json-escape-char` - 检测 JSON 合法转义字符
- `%match-json-escape-error` - 检测 JSON 非法转义序列
- `%no-match` - 构造未命中的匹配结果
- `%matched` - 构造命中的匹配结果
