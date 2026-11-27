# (liii highlight output-rate) 模块函数分类索引

运行时可调速的输出 sink：token bucket 限流，时钟与睡眠可注入，调速不改变文本内容。

## 查看函数文档

```bash
gf doc liii/highlight/output-rate "函数名"
```

## 函数分类索引

- `make-rate-limited-sink` - 构造可调速输出 sink（rate/burst/clock/sleep-fn 可配置）。
- `rate-limited-sink?` - 判断 sink 对象。
- `rate-limited-sink-write!` - 按当前速率分批写出文本。
- `rate-limited-sink-set-rate!` - 运行时动态调速（#f 取消限速）。
- `rate-limited-sink-flush!` - 刷新输出端口。
