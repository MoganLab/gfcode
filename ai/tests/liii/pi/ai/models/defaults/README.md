# (liii pi ai models defaults) 测试导览

本库定义全局默认供应商，以及各供应商在没有显式选择模型时使用的模型标识。

## 运行测试

```bash
gf test ai/tests/liii/pi/ai/models/defaults/
```

## 测试文件索引

- `PI_DEFAULT_PROVIDER-test.scm`：验证全局默认供应商为 `deepseek`。
- `pi-provider-default-model-test.scm`：验证各供应商的默认模型以及未知供应商的回退值。
