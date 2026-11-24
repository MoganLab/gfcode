# (liii pi ai auth device-info) 模块函数索引

`(liii pi ai auth device-info)` 生成 Kimi Coding 设备信息请求头（`X-Msh-*`，对齐 Kimi CLI 的 `createKimiDeviceHeaders`）。Kimi 服务端依据 `X-Msh-Device-Name` 在账号中心"登录设备"列表展示设备名；gfcode 在主机名后追加 `(gfcode/<os-type>)` 后缀，便于区分不同操作系统、不同客户端的登录记录。

设备 UUID 持久化在 `~/.gf/agent/device_id`（首次随机生成，之后复用；非 Windows chmod 0600），读写失败静默降级，不影响登录。

使用时导入：

```scheme
(import (liii pi ai auth device-info))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-device-headers
```

## 函数分类索引

### 设备信息头
- `pi-device-headers` - 完整六元 X-Msh-* 请求头 alist
- `pi-device-id` - 读/生成并持久化设备 UUID（~/.gf/agent/device_id）

### 纯函数与常量
- `PI_DEVICE_PLATFORM` - 平台标识（gfcode）
- `PI_DEVICE_VERSION` - 客户端版本（与 gfproject.json 同步）
- `%pi-ascii-header` - HTTP header 值 ASCII 清洗（非 0x20-0x7E 剔除，空回退）
- `%pi-device-name` - 设备名：<hostname> (gfcode/<os-type>)
- `%pi-device-model` - 设备型号：<os-type> <os-arch>
- `%pi-os-version` - 系统版本：Windows 取 OS 环境变量，其余取 uname -sr
