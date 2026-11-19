# (liii pi code config headers) 测试导览

`(liii pi code config headers)` 把模型目录中的 `headers` 对象解析为请求层
header alist：环境变量在配置阶段插值，`${API_KEY}` 保留到每次请求时按当前
凭据展开，以支持密钥轮换。

## 运行测试

```bash
bin/gf test code/tests/liii/pi/code/config/headers/
```

## 测试文件索引

- `pi-resolve-request-headers-test.scm` — header 名称/取值校验、环境变量插值、
  `${API_KEY}` 保留与缺失密钥报错
