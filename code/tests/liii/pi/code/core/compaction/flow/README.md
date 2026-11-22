# (liii pi code core compaction flow) 模块函数索引

`(liii pi code core compaction flow)` 负责自动压缩的编排：构造压缩摘要、
按配置生成自动压缩选项（compactor），并在压缩完成后把上下文标记为未知
（对齐上游 pi 的 compaction 流程）。

使用时导入：

```scheme
(import (liii pi code core compaction flow))
```

## 1. 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc pi-make-compaction-option
```

## 2. 函数分类索引

### 摘要输出
- `pi-format-compaction-summary` - 将压缩结果格式化为一行摘要（压缩条数、保留条数、压缩前 Token 数）

### 自动压缩选项
- `pi-make-compaction-option` - 构造自动压缩选项（未启用时返回 #f）
  （compactor 执行时解析最新 effective-cfg，不固定为创建时的初始模型）

### 压缩窗口解析
- `pi-resolve-compaction-window` - 解析当前模型的上下文窗口（all-in-one
  取实际/保守节点窗口，普通模型取 metadata contextWindow）

## 3. 压缩在会话中的位置

会话流程（`(liii pi code modes flow)`）经本模块构造压缩选项后交给 Agent
主循环；Agent 每轮请求前调用 compactor，compactor 判定是否需要压缩：

```
Agent 每轮准备（请求前）
   │
   ▼
compactor(msgs)
   │  ① 解析本次 effective-cfg（prepare-request 钩子；未安装时沿用创建时 cfg）
   │  ② pi-resolve-compaction-window 按本次 cfg 取上下文窗口
   │  ③ 估算 Token 超过窗口阈值 → 执行压缩；否则原样返回 msgs
   ▼
需要压缩：落盘当前消息 → pi-compact-session! 生成摘要 → 投影重建上下文
          → stderr 输出摘要行 → emit 'compaction 通知前端占比转 "?"
不需要：  原样返回 msgs（本次请求照常进行）
```

## 4. 为什么要按本次 effective-cfg 解析

压缩判定依赖两个随时可变的东西：**上下文窗口**（不同模型窗口不同）与
**摘要请求的模型/认证**（压缩本身也是一次模型请求）。若 compactor 固定使用
创建闭包时的初始模型，运行中切换模型后会出现：

- 切到更大窗口的模型：仍按旧窗口过早压缩，浪费上下文；
- 切到更小窗口的模型：按旧窗口判定不压缩，请求却已超出新模型窗口；
- 摘要请求发往旧模型的认证与端点，切 provider 后认证错配。

因此 compactor 与 Agent 请求边界共用同一约定：执行时调用 cfg 的
`prepare-request` 钩子（如有）取得本次有效配置，窗口、摘要模型与认证三者
一致。未安装钩子（CLI/非交互场景）时直接沿用创建时 cfg，行为不变。

## 5. all-in-one 的压缩窗口

all-in-one 伪模型的"窗口"取决于实际提供服务的物理节点，而节点在链路中
动态选择，无法在创建时固定：

| 链路状态 | 取值 |
| --- | --- |
| 有已就绪的粘性节点（未冷却） | 该实际节点的上下文窗口 |
| 未建立粘性 / 粘性节点冷却中 | 整条链路候选节点窗口的最小值（保守值） |

节点窗口按"模型库 store → 内置目录 → 1M 兜底"的顺序解析，杜绝硬编码
或沿用过期/故障节点的窗口。

## 6. 相关模块

| 模块 | 职责 |
| --- | --- |
| `(liii pi code core compaction session)` | 单次压缩执行（摘要生成、条目落盘） |
| `(liii pi code core compaction tokens)` | 上下文 Token 估算与压缩阈值判定 |
| `(liii pi code modes flow)` | 压缩选项的调用方（会话流程装配） |
| `(liii pi agent loop)` | Agent 主循环（每轮请求前调用 compactor） |
