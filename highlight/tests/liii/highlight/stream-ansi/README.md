# (liii highlight stream-ansi) 模块函数分类索引

结构事件到 ANSI 文本的渲染适配器：只渲染完整行，跨段高亮状态延续，EOF 时交付尾行。

## 查看函数文档

```bash
gf doc liii/highlight/stream-ansi "函数名"
```

## 函数分类索引

- `make-ansi-structure-emitter` - 构造 ANSI 渲染适配器。
- `ansi-structure-emitter?` - 判断适配器对象。
- `ansi-structure-emitter-feed!` - 渲染结构流原文账本的新增完整行。
- `highlight-port-to-ansi-streaming` - 端口级流式高亮（按块读取，结构事件驱动输出）。
