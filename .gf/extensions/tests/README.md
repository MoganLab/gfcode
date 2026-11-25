# tps 项目级扩展测试

`tests/` 验证 `../tps.scm` 的加载、agent 事件处理和 token 吞吐量统计。

从仓库根目录运行：

```bash
gf test .gf/extensions/tests
```

- `tps-test.scm` - 验证扩展加载、usage 累加、格式化输出与通知回退行为
