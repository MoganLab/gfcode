# (liii pi code config thinking) 测试导览

`(liii pi code config thinking)` 按 `models-store` 目录条目查询模型能力：
是否支持 reasoning、可用思考级别集合；目录条目缺失时按上游语义回退到全集。

## 运行测试

```bash
bin/gf test code/tests/liii/pi/code/config/thinking/
```

## 测试文件索引

- `pi-model-supports-thinking-p-test.scm` — reasoning 元数据查询与缺省回退
- `pi-model-available-thinking-levels-test.scm` — 可用思考级别集合与
  reasoning 关闭时的收敛
