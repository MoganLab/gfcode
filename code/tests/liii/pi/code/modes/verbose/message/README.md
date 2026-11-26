# (liii pi code modes verbose message) 模块函数分类索引

`(liii pi code modes verbose message)` 提供 verbose 模式的消息缓冲、按行输出、尾部刷新，以及 message 事件（start/update/end）的辅助处理逻辑。

使用时导入：

```scheme
(import (liii pi code modes verbose message))
```

## 查看函数文档

```bash
gf doc display-message-line
gf doc flush-message-lines
gf doc flush-message-tail
```

## 函数分类索引

### 消息缓冲与输出
- `display-message-line` - 输出消息一行，首行带 💬 前缀，续行不带
- `flush-message-lines` - 合并增量后按 \n 逐行打印并更新缓冲
- `flush-message-tail` - message 结束时打印剩余尾部并复位缓冲
