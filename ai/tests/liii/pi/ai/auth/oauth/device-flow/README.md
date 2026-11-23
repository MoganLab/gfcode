# (liii pi ai auth oauth device-flow) 模块函数索引

`(liii pi ai auth oauth device-flow)` 提供 RFC 8628 设备码通用轮询循环，翻译自上游 pi 的 `pollOAuthDeviceCodeFlow`。

使用时导入：

```scheme
(import (liii pi ai auth oauth device-flow))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-device-flow-poll
```

## 函数分类索引

### 轮询
- `pi-device-flow-poll` - 设备码轮询循环，返回 complete 的 value，失败/取消/超时抛错

### 常量
- `PI_DEVICE_FLOW_CANCEL_MESSAGE` - 取消消息
- `PI_DEVICE_FLOW_TIMEOUT_MESSAGE` - 超时消息
- `PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE` - slow_down 超时消息
