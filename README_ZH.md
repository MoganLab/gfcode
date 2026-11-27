# gfcode

[English](README.md)

gfcode 是一款零依赖、兼容 Pi 的 Agent Harness。

gfcode 仅依赖 Goldfish Scheme，连同 Goldfish Scheme 的安装体积也不到 10 MB。它兼容 Pi 的 TUI 使用习惯与 JSONL 会话序列化，可在各种设备上轻量安装运行，也可嵌入 C/C++ 生态的应用中。

## 安装

先安装 [Goldfish Scheme](https://github.com/MoganLab/goldfish)：

```bash
# macOS
brew tap MoganLab/goldfish
brew install goldfish

# Windows（Scoop）
scoop bucket add goldfish https://github.com/MoganLab/scoop-goldfish
scoop install goldfish
```

然后安装最新版 gfcode：

```bash
gf get -g https://github.com/MoganLab/gfcode.git --force
```

通过 HTTP 代理安装（以端口 `7890` 为例）：

```bash
HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gf get -g https://github.com/MoganLab/gfcode.git --force
```

验证：

```bash
gf help | grep pi
```

## 代码审查

在交互界面输入 `/review`，或使用 `gf pi --code-review`。审查可用 Bash 查看差异；如需修改、构建或运行会写文件的测试，请在原工作区之外创建包含待审改动的临时副本，不要把改动同步回原件。

`write` 和 `edit` 不允许修改原工作区；Windows 上审查会禁用这两个工具。Bash 没有文件系统隔离，不写入原工作区是给模型的指令，而不是系统强制的权限限制。

## 配置

### 一键登录

目前仅 **Kimi Coding** 支持 OAuth 登录：

```bash
gf pi auth login --provider kimi-coding --oauth
```

其他供应商可以使用 API Key 登录：

```bash
gf pi auth login --provider <provider> --key <key>
```

也可以运行 `gf pi`，通过交互式 `/login` 命令选择 OAuth 或 API Key 登录。

### 交互式配置

使用配置界面启停供应商和模型，或设置特殊的 `all-in-one` 供应商。`all-in-one` 可以将多个模型组成故障切换链：

```bash
gf pi config
```

例如，当前 Coding Plan 额度用完后，`all-in-one` 可以自动切换到链中的下一个可用模型，无需中断当前会话。

---

## 面向 Agent 的模型配置

gfcode 内置 Google Gemini、Anthropic Claude、Kimi Coding、DeepSeek、MiniMax、Z.AI GLM、OpenCode 和 Qwen Token Plan 的模型，也支持本地 Ollama 模型。

列出全部内置及自定义模型和启用状态：

```bash
gf pi --list-models
gf pi --list-models gemini  # 可选的搜索关键词
```

### API Key 环境变量

非交互式配置可设置供应商对应的环境变量：

| 供应商               | 环境变量                                                                 |
| -------------------- | ------------------------------------------------------------------------ |
| `google`             | `GEMINI_API_KEY`                                                         |
| `anthropic`          | `ANTHROPIC_API_KEY`                                                      |
| `kimi-coding`        | `KIMI_API_KEY`                                                           |
| `deepseek`           | `DEEPSEEK_API_KEY`                                                       |
| `minimax-cn`         | `MINIMAX_CN_API_KEY` 或 `MINIMAX_API_KEY`                                |
| `zai-coding-cn`      | `ZAI_CODING_CN_API_KEY`、`ZAI_API_KEY`、`GLM_API_KEY` 或 `ZHIPU_API_KEY` |
| `opencode`           | `OPENCODE_API_KEY` 或 `OPENCODE_GO_API_KEY`                              |
| `qwen-token-plan-cn` | `QWEN_TOKEN_PLAN_TEAM_CN_API_KEY` 或 `QWEN_TOKEN_PLAN_CN_API_KEY`        |

设置环境变量后再运行 `gf pi`。

### 自定义供应商和模型

配置位于 `~/.gf/agent`。以下示例通过 Google Vertex AI 的 OpenAI 兼容端点，在内置 `google` 供应商中添加 DeepSeek V4.1 Flash。

将模型 ID 添加到 `~/.gf/agent/models/google.json`：

```json
{
  "models": ["deepseek-ai/deepseek-v4.1-flash-1017-maas"]
}
```

创建 `~/.gf/agent/models/google/deepseek-ai/deepseek-v4.1-flash-1017-maas.json`，并将 `<PROJECT_ID>` 替换为你自己的项目 ID：

```json
{
  "id": "deepseek-ai/deepseek-v4.1-flash-1017-maas",
  "name": "DeepSeek V4.1 Flash",
  "baseUrl": "https://aiplatform.googleapis.com/v1/projects/<PROJECT_ID>/locations/us-central1/endpoints/openapi/chat/completions",
  "api": "openai-completions",
  "headers": {
    "x-goog-api-key": "${API_KEY}"
  },
  "reasoning": true,
  "thinkingLevelMap": {
    "minimal": null,
    "low": "low",
    "medium": null,
    "high": "high",
    "max": "max"
  },
  "input": ["text", "image"],
  "cost": {
    "input": 0.3,
    "output": 1.2,
    "cacheRead": 0.006,
    "cacheWrite": 0
  },
  "contextWindow": 1000000,
  "maxTokens": 384000,
  "compat": {
    "supportsStore": false,
    "supportsDeveloperRole": false,
    "maxTokensField": "max_tokens",
    "requiresReasoningContentOnAssistantMessages": true,
    "thinkingFormat": "deepseek",
    "supportsStrictMode": true
  }
}
```

保存 API Key，然后运行模型：

```bash
gf pi auth login --provider google --key <key>
gf pi --provider google --model deepseek-ai/deepseek-v4.1-flash-1017-maas
```

如需新增供应商，创建包含 `baseUrl` 和 `api` 的 `models/<provider>.json`，再将其 ID 添加到 `models/providers.json`。支持 `openai`（OpenAI 兼容）、`anthropic` 和 `google` 协议。每个模型在 `models/<provider>/` 下使用独立的 JSON 文件配置；模型 ID 含 `/` 时使用对应的子目录。

### 模型白名单

`~/.gf/agent/models/providers.json` 是供应商白名单：文件存在且非空时，只启用列出的供应商。`models/<provider>.json` 中的 `models` 数组是该供应商的模型白名单，仅启用列出的模型，并按数组顺序展示。

可以通过 `gf pi config` 交互式启停供应商和模型，也可以直接编辑这些 JSON 文件。
