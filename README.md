# gfcode: A Pi-compatible Coding Agent

[中文](README_ZH.md)

gfcode is a zero-dependency Agent Harness compatible with Pi.

It requires only Goldfish Scheme, with a combined installation size of less than 10 MB. Compatible with Pi's TUI conventions and JSONL session serialization, gfcode runs lightweight installations on any device and can be embedded in C/C++ applications.

## Installation

First install [Goldfish Scheme](https://github.com/MoganLab/goldfish):

```bash
# macOS
brew tap MoganLab/goldfish
brew install goldfish

# Windows (Scoop)
scoop bucket add goldfish https://github.com/MoganLab/scoop-goldfish
scoop install goldfish
```

Then install the latest gfcode version:

```bash
gf get -g https://github.com/MoganLab/gfcode.git --ref @latest --force
```

Using an HTTP proxy (port `7890` in this example):

```bash
HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gf get -g https://github.com/MoganLab/gfcode.git --ref @latest --force
```

Verify:

```bash
gf help | grep pi
```

## Configuration

### One-command Login

Currently, only **Kimi Coding** supports OAuth login:

```bash
gf pi auth login --provider kimi-coding --oauth
```

For other providers, use an API key:

```bash
gf pi auth login --provider <provider> --key <key>
```

You can also run `gf pi` and use the interactive `/login` command to choose OAuth or API key login.

### Interactive Configuration

Use the configuration UI to enable providers and models, or to set up the special `all-in-one` provider, which combines models into failover chains:

```bash
gf pi config
```

For example, when your current Coding Plan reaches its usage limit, `all-in-one` can automatically switch to the next available model in the chain without interrupting the session.

---

## Model Configuration for Agents

gfcode provides built-in models from Google Gemini, Anthropic Claude, Kimi Coding, DeepSeek, MiniMax, Z.AI GLM, OpenCode, and Qwen Token Plan. Local Ollama models are also supported.

List all built-in and custom models with their activation status:

```bash
gf pi --list-models
gf pi --list-models gemini  # Optional search term
```

### API Key Environment Variables

For non-interactive setup, configure an API key using the corresponding environment variable:

| Provider | Environment variable |
|---|---|
| `google` | `GEMINI_API_KEY` |
| `anthropic` | `ANTHROPIC_API_KEY` |
| `kimi-coding` | `KIMI_API_KEY` |
| `deepseek` | `DEEPSEEK_API_KEY` |
| `minimax-cn` | `MINIMAX_CN_API_KEY` or `MINIMAX_API_KEY` |
| `zai-coding-cn` | `ZAI_CODING_CN_API_KEY`, `ZAI_API_KEY`, `GLM_API_KEY`, or `ZHIPU_API_KEY` |
| `opencode` | `OPENCODE_API_KEY` or `OPENCODE_GO_API_KEY` |
| `qwen-token-plan-cn` | `QWEN_TOKEN_PLAN_TEAM_CN_API_KEY` or `QWEN_TOKEN_PLAN_CN_API_KEY` |

Set the environment variable before running `gf pi`.

### Custom Providers and Models

Configuration is stored under `~/.gf/agent`. The following example adds DeepSeek V4.1 Flash through Google Vertex AI's OpenAI-compatible endpoint to the built-in `google` provider.

Add the model ID to `~/.gf/agent/models/google.json`:

```json
{
  "models": ["deepseek-ai/deepseek-v4.1-flash-1017-maas"]
}
```

Create `~/.gf/agent/models/google/deepseek-ai/deepseek-v4.1-flash-1017-maas.json`. Replace `<PROJECT_ID>` with your own project ID:

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

Save the API key and run the model:

```bash
gf pi auth login --provider google --key <key>
gf pi --provider google --model deepseek-ai/deepseek-v4.1-flash-1017-maas
```

For a completely new provider, create `models/<provider>.json` with `baseUrl` and `api`, then add its ID to `models/providers.json`. Supported protocols are `openai` (OpenAI-compatible), `anthropic`, and `google`. Each model is defined in its own JSON file under `models/<provider>/`; use subdirectories when the model ID contains `/`.

### Model Whitelist

`~/.gf/agent/models/providers.json` is the provider whitelist. If it exists and is non-empty, only listed providers are enabled. The `models` array in `models/<provider>.json` is the model whitelist for that provider; only listed models are enabled and shown in that order.

Use `gf pi config` to enable or disable providers and models interactively, or edit these JSON files directly.
