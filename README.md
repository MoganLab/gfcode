# gfcode

`gf pi` 命令的实现项目。

## 注册到 Goldfish（v18.11.63 起必需）

> **版本分界**：`gf pi` 在 **Goldfish v18.11.62** 及更早版本中是内置子命令，开箱即用；
> 从 **v18.11.63** 开始，`gf pi` 被拆分为独立项目（即本项目 gfcode），不再随 Goldfish
> 内置，需要在 `~/.gf/gfproject.json` 中注册后才能使用 `bin/gf pi`。
> 这是一个过渡期方案：后续 gfcode 会单独发布一个二进制，届时不再依赖本文的用户层注册。

Goldfish 通过项目配置的 `tools` 节点解析 `gf <命令>`。`gf pi` 从 v18.11.63 起不再内置，
需要用户在用户层配置 `~/.gf/gfproject.json` 中登记本项目的路径。

假定本项目克隆在 `~/git/gfcode`，用户层配置如下：

```json
{
  "tools": {
    "pi": {
      "tools_dir": "~/git/gfcode",
      "tool": "code",
      "organization": "liii",
      "module": "pi/code/cli",
      "description": {
        "en_US": "gf pi subcommand (gfcode)",
        "zh_CN": "gf pi 子命令（gfcode）"
      }
    }
  }
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `pi` | 注册的命令名，决定 `bin/gf pi` 这一命令 |
| `tools_dir` | 本项目根目录，支持 `~` 展开；相对路径以**本条配置所在的 `gfproject.json` 目录**（即 `~/.gf`）为基准 |
| `tool` | 本项目 `gfproject.json` 中 `domains` 下要使用的 domain 名（本仓库为 `code`） |
| `organization` / `module` | 工具模块的库名，即 `(liii pi code cli)`，其 `main` 为命令入口 |
| `description` | `bin/gf help` 中显示的命令描述，可只写 `zh_CN` |

创建步骤：

```bash
mkdir -p ~/.gf
# 若已存在 ~/.gf/gfproject.json，请把上面的 "pi" 节点合并进现有 "tools" 中
cat > ~/.gf/gfproject.json <<'JSON'
{
  "tools": {
    "pi": {
      "tools_dir": "~/git/gfcode",
      "tool": "code",
      "organization": "liii",
      "module": "pi/code/cli",
      "description": { "zh_CN": "gf pi 子命令（gfcode）" }
    }
  }
}
JSON
```

验证：

```bash
bin/gf help | grep pi          # 应能看到 pi 命令行
bin/gf pi -p "say hello"      # 实际运行（需要已配置 provider 与 API key）
```

说明：

- 本项目自身的 `gfproject.json` 的 `domains` 由 `gf pi` 在运行时自动注入加载路径，
  无需复制到 `~/.gf/gfproject.json`。
- 项目层（当前工作目录的 `gfproject.json`）若也注册了同名 `pi`，**项目层覆盖用户层**，
  便于在 gfcode 仓库内直接开发调试。
- 只影响 `gf pi` 命令解析；`gf test` / `gf fmt` / `gf check` 等项目语义不变。
