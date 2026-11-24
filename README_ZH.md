# gfcode

[English](README.md)

`gf pi` 命令的实现项目。

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

然后安装最新版 gfcode。以下命令需要 `curl` 和 `jq`：

```bash
gf get -g https://github.com/MoganLab/gfcode.git --ref "$(curl -fsSL https://api.github.com/repos/MoganLab/gfcode/tags | jq -r '.[0].name')" --force
```

通过 HTTP 代理安装（以端口 `7890` 为例）：

```bash
HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gf get -g https://github.com/MoganLab/gfcode.git --ref "$(HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 curl -fsSL https://api.github.com/repos/MoganLab/gfcode/tags | jq -r '.[0].name')" --force
```

验证：

```bash
gf help | grep pi
```
