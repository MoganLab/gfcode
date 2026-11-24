# gfcode

`gf pi` 命令的实现项目。

## 安装

> **版本分界**：`gf pi` 在 **Goldfish v18.11.62** 及更早版本中是内置子命令，开箱即用；
> 从 **v18.11.63** 开始，`gf pi` 被拆分为独立项目（即本项目 gfcode），不再随 Goldfish
> 内置，需要用 `gf get` 安装后才能使用 `gf pi`。
> 这是一个过渡期方案：后续 gfcode 会单独发布一个二进制，届时安装说明会进一步简化。

本项目依赖 **Goldfish v18.11.66**，请先升级到该版本或更高版本。

```bash
gf get -g https://github.com/MoganLab/gfcode
```

验证：

```bash
gf help | grep pi          # 应能看到 pi 命令行
gf pi -p "say hello"      # 实际运行（需要已配置 provider 与 API key）
```

## 从源码开发

若需在仓库内直接开发调试，克隆本项目后进入目录即可使用 `gf pi`（项目自带 `gfproject.json` 已注册 `pi`，项目层配置覆盖用户层）：

```bash
git clone https://github.com/MoganLab/gfcode ~/git/gfcode
cd ~/git/gfcode
gf pi -p "say hello"
```

说明：

- 项目自身的 `gfproject.json` 的 `domains` 由 `gf pi` 在运行时自动注入加载路径。
- 项目层（当前工作目录的 `gfproject.json`）若注册了同名 `pi`，**项目层覆盖用户层**，便于在 gfcode 仓库内直接开发调试。
- 只影响 `gf pi` 命令解析；`gf test` / `gf fmt` / `gf check` 等项目语义不变。
