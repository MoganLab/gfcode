# gfcode: A Pi-compatible Coding Agent

[中文](README_ZH.md)

The implementation of the `gf pi` command.

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

Then install the latest gfcode version. The command requires `curl` and `jq`:

```bash
gf get -g https://github.com/MoganLab/gfcode.git --ref "$(curl -fsSL https://api.github.com/repos/MoganLab/gfcode/tags | jq -r '.[0].name')" --force
```

Using an HTTP proxy (port `7890` in this example):

```bash
HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gf get -g https://github.com/MoganLab/gfcode.git --ref "$(HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 curl -fsSL https://api.github.com/repos/MoganLab/gfcode/tags | jq -r '.[0].name')" --force
```

Verify:

```bash
gf help | grep pi
```
