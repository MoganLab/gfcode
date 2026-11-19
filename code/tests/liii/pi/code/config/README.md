# (liii pi code config) 配置解析与用户目录测试导览

`(liii pi code config)` 负责解析 `gf pi` 的命令行参数与用户配置目录：
`settings.json`、`auth.json`、`models/providers.json` 白名单以及
`models/<provider>/<model>.json` 模型目录。测试覆盖配置加载、provider
与模型解析、API key/代理选择、思考级别以及配置写回。

## 模块组成

- `code/liii/pi/code/config.scm` — 配置解析入口与公开 API
- `code/liii/pi/code/config/user-providers.scm` — provider 白名单加载与 headers 读取
- `code/liii/pi/code/config/user-catalog.scm` — 用户模型目录构建
- `code/liii/pi/code/config/user-models.scm` — 模型元数据加载与字段合并
- `code/liii/pi/code/config/model-files.scm` — `models/<provider>/<model>.json` 定位与枚举
- `code/liii/pi/code/config/user-fs.scm` — 用户配置文件读写
- `code/liii/pi/code/config/settings.scm` — settings.json 解析
- `code/liii/pi/code/config/thinking.scm` — 模型思考能力与可用级别查询
- `code/liii/pi/code/config/headers.scm` — 模型 headers 解析与 `${API_KEY}` 展开

## 运行测试

```bash
bin/gf test code/tests/liii/pi/code/config/
```

## 测试文件索引

- `resolve-pi-config-test.scm` — `resolve-pi-config`：默认配置、命令行覆盖
- `resolve-pi-config-env-test.scm` — 环境变量污染隔离
- `resolve-pi-config-dir-test.scm` — 配置目录优先级
- `resolve-pi-config-user-catalog-test.scm` — 用户目录驱动的 provider/模型路由
- `resolve-pi-config-headers-test.scm` — provider/model headers 合并与 CLI 配置注入
- `headers/pi-resolve-request-headers-test.scm` — 请求头模板解析、校验与环境变量插值
- `resolve-goldpi-config-test.scm` — `resolve-goldpi-config` 别名
- `resolve-active-tools-test.scm` — 生效工具列表计算
- `config-worker-registry-test.scm` — worker 配置注册
- `gf-get-config-dir-test.scm` — `gf-get-config-dir` 目录选择
- `pi-cfg-config-dir-test.scm` — 从 cfg 读取配置目录
- `pi-cfg-provider-api-test.scm` — provider 协议标识选择
- `pi-cfg-provider-proxy-test.scm` — provider 级代理选择
- `pi-resolve-proxy-url-test.scm` — 全局代理 URL 解析
- `thinking/pi-model-available-thinking-levels-test.scm` — 模型可用思考级别
- `thinking/pi-model-supports-thinking-p-test.scm` — 模型是否支持思考级别
- `pi-missing-credential-msg-test.scm` — 凭证缺失提示
- `augment-pi-config-test.scm` — 扩展 augmenter 增强配置
