# (liii pi app interactive app-highlight) 模块函数索引

- `%pi-app-pump-highlight!`：向展示 worker 非阻塞提交当前版本的请求，队列已满时留到下次轮询。
- `%pi-app-handle-highlight!`：按轮次、调用编号与版本匹配结果，只更新对应的卡片。

```bash
gf test app/tests/liii/pi/app/interactive/app-highlight
```
