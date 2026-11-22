# (liii pi code modes flow) 模块函数索引

`(liii pi code modes flow)` 负责非交互（脚本）模式的会话流程：构造系统提示词、
落盘首轮用户消息、以解析出的超时驱动 Agent 主循环，并以 JSON 行输出事件
（对齐上游 pi 的非交互运行模式）。TUI 交互模式的后台 Worker 也复用同一
会话流程，通过 `session-file` 参数跨消息保持上下文连续。

使用时导入：

```scheme
(import (liii pi code modes flow))
```

## 1. 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc run-session-flow
```

## 2. 函数分类索引

### 提示词与落盘
- `prepare-system-prompt` - 构造系统提示词（合并 CLI 覆盖、追加提示与项目上下文）
- `persist-initial-user-msg!` - 将首轮用户消息追加落盘到会话文件

### Agent 循环与事件输出
- `run-agent-loop-with-timeout` - 以解析出的超时与轮数上限驱动 Agent 主循环
  （普通 Provider 与 all-in-one 的分发按每次请求的 effective-cfg 动态判断）
- `emit-json-event` - 将事件序列化为 JSON 行写入标准输出

### 会话流程
- `run-session-flow` - 单会话模式运行一轮对话并回调结束处理
- `run-compact-flow` - 手动压缩最近一次会话（可继续本轮请求）

## 3. 模块在调用链中的位置

`gf pi` 命令按运行模式分发（`liii pi code modes` 的 `dispatch-pi`），本模块承担
其中三种非交互模式的会话流程主体：

| 模式 | 触发条件 | emit | 结束处理 |
| --- | --- | --- | --- |
| print | `--print` / 管道输入输出 | `#f`（无事件） | 输出最终 assistant 文本 |
| verbose | `--verbose` / 非 TTY | 实时事件渲染 | 输出退出码 |
| json | `--mode json` | `emit-json-event`（JSON 行） | 返回 0 |

interactive（TUI）模式不经过 `dispatch-pi`：前台 App 把用户消息投递给后台
Worker，Worker 同样调用本模块的 `run-session-flow`（`session-file` 复用同一
会话文件），因此本模块的行为对交互模式同样生效。

## 4. run-session-flow 会话流程

一次 `run-session-flow` 调用的完整生命周期：

```
解析配置与技能
   │
   ▼
定位会话文件（新建 / --continue / --resume / TUI 复用 session-file）
   │
   ▼
投影会话历史（有旧会话时）→ 合并投影状态（模型、思考等级）
   │
   ▼
逐条消息循环：initial-msg + rest-msgs
   │  ├─ 追加 user 消息并落盘
   │  ├─ 构造压缩选项（compactor）
   │  ├─ run-agent-loop-with-timeout 驱动 Agent 主循环
   │  └─ Agent 结束后增量落盘全部新消息
   ▼
on-finish 回调（由模式决定：输出文本 / 退出码 / 通知 TUI）
```

关键点：

- **单会话模型**：`initial-msg` 与 `rest-msgs` 属同一会话文件，前一条消息的
  回复自动成为后一条的上下文（对齐上游 pi 单会话模型）。
- **投影状态合并**：恢复会话时，`pi-resolve-session-state` 把会话记录中保存
  的模型与思考等级合并进 cfg，保证恢复后的首轮请求与上次会话一致。
- **逐条落盘**：每条消息开始前落盘 user 消息，Agent 结束后落盘增量回复；
  压缩发生时（见第 6 节）compactor 内部自行落盘，state 向量同步推进。

## 5. run-agent-loop-with-timeout 请求分发

本函数把解析出的超时、轮数上限与压缩选项装配进 Agent 主循环，并提供两类
测试注入口（`probe-fn` / `request-fn`）。核心职责是**请求分发**：把 Agent
循环发来的 Provider 请求路由到正确的适配器：

```
Agent 主循环（每次新请求）
   │  config 已是本次 effective-cfg
   │ （由 agent 层的 prepare-request 钩子解析，见其模块文档）
   ▼
本次 provider == "all-in-one" ？
   ├─ 是：pi-all-in-one-request-stream（注入 agent emit 上报实际节点）
   └─ 否：request-fn（测试注入）或 pi-request-provider-stream（默认）
```

- **按本次请求动态判断**：普通 Provider 与 all-in-one 的分发不能在 run 启动
  时按初始 provider 固化——运行中在普通模型与 all-in-one 之间切换（经
  `prepare-request` 钩子）时，后续请求仍进入正确适配器。
- **all-in-one 的 emit 注入**：把 agent 的 emit 回调写进请求配置，供 all-in-one
  适配器上报实际物理节点（footer 显示当前节点）。
- **探活参数**：`probe-fn` 透传给 all-in-one 适配器做节点探活，测试可注入。

## 6. 自动压缩的接入点

`run-session-flow` / `run-compact-flow` 经 `pi-make-compaction-option`（见
`(liii pi code core compaction flow)` 模块）构造压缩选项，Agent 循环在每轮
请求前调用 compactor。与本模块相关的两点：

- compactor 执行时解析最新 effective-cfg：运行中切模后，压缩窗口与摘要请求
  的模型/认证随本次生效配置同步，不固定为会话开始时的初始模型。
- 压缩发生后，上下文由投影入口统一重建，state 向量同步推进，后续落盘与
  上下文占比计算基于压缩后的历史。

## 7. 相关模块

| 模块 | 职责 |
| --- | --- |
| `(liii pi agent loop)` | Agent 主循环引擎（ReAct 循环、事件、prepare-request 钩子） |
| `(liii pi code core compaction flow)` | 自动压缩选项构造与压缩窗口解析 |
| `(liii pi code modes output)` | print / verbose 模式的结果输出 |
| `(liii pi code modes verbose)` | verbose 模式的实时事件渲染 |
| `(liii pi code all-in-one request)` | all-in-one 链路的请求适配器 |
| `(liii pi code core session-manager)` | 会话文件落盘与投影 |
