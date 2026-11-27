# (liii highlight stream) 模块函数分类索引

本模块实现结构事件流：按 syntax JSON 的 segments 声明产生语义结构事件，输入块只是传输单位，不构成结构边界。

## 事件形式

```text
(open name role metadata)         结构打开
(content text spans)              已确定的原文片段 + 局部高亮 spans
(close name role closed? text)    结构关闭；text 为完整原文
(error reason detail)             unexpected-close / mismatched-delimiter / unexpected-eof
```

## 语义要点

- `feed!` 块边界不是结构边界：未闭合结构保持打开，已确定正文立即处理。
- 开始标记的严格前缀在块末尾时暂存，等待后续输入判定。
- 真实换行闭合本行打开的 `line` 结构；换行符归入 content。
- `finish!` 幂等：EOF 时 line 结构正常闭合，其余按 `on-eof` 策略交付未闭合结构。
- 嵌套 close 的完整原文并入父结构累积文本。

## 查看函数文档

```bash
gf doc liii/highlight/stream "函数名"
```

## 函数分类索引

- `make-structure-stream` - 构造结构事件流（def + 事件回调）。
- `structure-stream?` - 判断结构流对象。
- `structure-stream-feed!` - 输入一个传输块，产生结构事件。
- `structure-stream-finish!` - EOF 收尾，按策略关闭未闭合结构。

## 集成测试

- `structure-stream-markdown-heading-test.scm` - markdown.json H1–H6 单行标题结构流。
- `structure-stream-markdown-code-test.scm` - markdown fenced code 多行结构流。
- `structure-stream-nested-test.scm` - 通用嵌套分隔符结构与容错。
- `structure-stream-scheme-list-test.scm` - scheme.json list 结构流。
- `structure-stream-json-container-test.scm` - json.json object/array 结构流。
- `structure-stream-cpp-delimiter-test.scm` - cpp.json brace/paren/bracket 结构流。
- `structure-stream-text-test.scm` - 原文账本与输入严格一致。
