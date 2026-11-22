# (liii pi agent loop) 模块函数索引

`(liii pi agent loop)` 提供 Agent 对话主循环的驱动引擎与单步状态机，负责多轮工具调用循环、上下文压缩检查、系统提示词动态解析以及生命周期事件的派发。

使用时导入：

```scheme
(import (liii pi agent loop))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc run-agent-loop
```

## 函数分类索引

### 主循环驱动
- `run-agent-loop` - 执行 Agent 完整的多轮工具调用与事件驱动主循环
- `pi-step-agent-turn` - 执行单轮模型请求与响应解析，提取工具调用与停止原因
  （每次新请求前调用可选 prepare-request 钩子解析最新 effective-cfg）

### 提示词与上下文
- `pi-resolve-turn-system-prompt` - 解析单轮系统提示词并动态注入预算与时间信息
- `pi-maybe-compact` - 检查上下文是否超出阈值并在需要时执行自动压缩

### 工具调用处理
- `pi-handle-tool-use` - 处理单轮模型输出的工具调用执行并更新消息历史

### 生命周期与事件
- `pi-finish-agent-turn` - 结束单轮对话并派发 turn_end 和扩展事件
- `pi-notify-turn-end` - 派发单轮结束事件 turn_end
- `pi-emit-agent-end` - 派发整个 Agent 会话结束事件 agent_end
- `pi-emit-agent-error` - 构造并派发 Agent 异常错误事件

---

## 什么是 Agent Loop（ReAct Loop）

从人与 Agent 交互的角度看：传统问答是"一问一答"，一次请求得到一次回复；而用户向 Agent 提交的是一个**任务**（例如"修复失败的测试"），一次问答无法完成，Agent 必须自主多轮工作。这就是经典的 **ReAct Loop**（Reasoning + Acting，Yao et al., 2022）：模型交替执行"推理"与"行动"，用行动产生的观察结果驱动下一步推理，而不是一次性规划到底：

```
用户任务 ──► [ 思考（Reasoning，模型请求）──► 行动（Acting，执行工具）──► 观察（Observation，结果回填） ] × N ──► 最终答复
```

- **思考（Reasoning）**：带着当前全部历史请求模型。模型要么直接给出最终文本答复（任务完成，自然停止），要么发起工具调用
- **行动（Acting）**：逐个执行模型请求的工具（读文件、改代码、跑命令……），可被用户中止或扩展拦截
- **观察（Observation）**：工具结果作为 toolResult 消息回填历史（本地操作，不请求模型）；带着全部观察发起的下一轮思考才是一次新的模型请求

与静态的"先规划后执行"相比，ReAct 的优势在于每一步行动都基于最新观察：跑了个测试发现失败，下一轮思考就针对失败原因调整；这也正是模型 `stop-reason` 为 `toolUse` 时循环继续、为 `stop` 时循环结束的直接体现。`run-agent-loop` 就是驱动这个循环的状态机，一次调用对应 Agent 处理一个任务的完整过程。循环期间用户并非只能等待：

| 用户交互 | 机制 | 生效时机 |
| --- | --- | --- |
| 追加引导（steering） | config 的 `get-steering-messages` 轮询 | 下一轮请求前注入为 user 消息，实时改变 Agent 方向 |
| 排队跟进（follow-up） | `get-follow-up-messages` 轮询 | Agent 自然停止时自动接续执行下一条任务 |
| 中止（ESC） | `pi-aborted?` 检查点 | 主循环 / 工具边界立即停止，不再发起新请求 |
| 运行中切模 | `prepare-request` 钩子 | 下一次模型请求即使用新配置 |
| 全过程可见 | `emit` 事件流 | 每条消息、每个工具调用实时上报 UI |

循环在以下情况结束：模型自然停止（任务完成）、用户中止、轮数或时间预算耗尽、请求错误。

## 会话生命周期

```
用户任务
   │
   ▼
┌───────────────────── 一轮（turn）─────────────────────┐
│ 前置检查（中止 / 超时 / 轮数上限）                       │
│ ① 上下文压缩      ② steering 注入      ③ 系统提示解析   │
│ ④ 模型请求（流式；prepare-request 解析最新配置）        │
│    │                                                  │
│    ├─ toolUse → ⑤ 工具执行批次 → ⑥ turn_end ──┐        │
│    │           （结果回填为观察）               │        │
│    │           未终止：回到 ① 进入下一轮 ◄─────┘        │
│    │                                                  │
│    └─ stop / length / error / aborted ────────────────┼──► 退出循环
└───────────────────────────────────────────────────────┘
   │
   ▼
自然停止（stop / length / 工具批次终止）？
   ├─ 是 ──► 轮询 steering / follow-up：有消息 → 注入续跑（回到下一轮）；无 → 结算
   └─ 否（error / aborted）──► 错误结算
   │
   ▼
结算：turn_end → agent_end（成本汇总）→ agent_settled，返回最终消息历史
```

### 1. 启动

`emit 'agent_start` 与首轮 `'turn_start`；`emit-initial?` 为真时逐条上屏初始消息；计算会话截止时间 `deadline-sec`（仅 `session-timeout > 0` 时）。

### 2. 每轮前置检查

每轮循环开始处依次检查：用户中止（直接以 aborted 结算，返回已有消息）、会话超时、轮数上限（后两者构造 error 消息走错误结算）。通过后进入本轮。

### 3. 单轮准备（请求前三件事）

1. `pi-maybe-compact`：上下文超过阈值时压缩历史（`compaction` 配置的 `compactor` 钩子）
2. steering 注入：轮询 `get-steering-messages`，有排队消息则转为 user 消息追加并上屏
3. `pi-resolve-turn-system-prompt`：解析系统提示词；仅在轮数/时间预算临界时附加静态 `<budget_warning>` 告警（不含逐轮变化的数字，保证前缀缓存不失效）

### 4. 模型请求（pi-step-agent-turn）

先经 `prepare-request` 钩子解析最新 effective-cfg（运行中切模的生效点），再调用 `request-fn` 发起流式请求，流式期间持续 `emit 'message_update`。响应附加成本后 `emit 'message_start` / `'message_end`，返回新消息、stop-reason 与工具调用列表。

### 5. 工具执行（stop-reason = toolUse）

逐个执行工具调用：`emit 'tool_execution_start` → 扩展桥 `tool_call` 事件（可拦截 / 改写入参 / 终止运行）→ 执行器运行（bash 支持流式 `tool_execution_update`）→ `emit 'tool_execution_end` 与工具结果消息上屏。批次语义：前一个工具 terminate 或用户中止则跳过剩余调用。结束后 `emit 'turn_end`（携工具结果）；未终止则 `emit 'turn_start` 进入下一轮，工具批次终止则视为自然停止进入停止决策。

### 6. 停止决策（自然停止）

轮询 steering，其次 follow-up：任一有排队消息则注入、`emit 'turn_start` 续跑下一轮；皆空则进入结算。这保证用户在 Agent 即将停止时排队的消息不会丢失，而是自动接续执行。

### 7. 结算

- **正常结算**（`pi-finish-agent-turn`）：stop-reason 为 length 时先为未执行的工具调用补失败结果；`emit 'turn_end` → `'agent_end`（携最终消息列表与成本汇总）→ `'agent_settled`
- **错误结算**（`pi-emit-agent-error` 或循环边界的中止分支）：构造 stop-reason 为 error 的 assistant 消息，emit 完整事件序列后同样以 `'agent_end` / `'agent_settled` 收尾（aborted 时 `'agent_settled` 携 `#t`，TUI 依此解锁输入队列）

`run-agent-loop` 返回最终完整消息历史列表，由上层（如 TUI worker）落盘会话文件。

### 关键设计点

- **prepare-request 钩子**：每次新的 Provider 请求前排空选择通道并返回本次有效的 effective-cfg，使运行中切模立即对下一次请求生效；未配置时沿用传入 config，保持 CLI 与非交互调用兼容。已开始的请求不被中断。
- **决策状态机**：`%run-agent-turn` 返回决策 alist（`continue` / `hard-stop` / `stop-check`），统一携带 `msgs` / `stop-reason` / `tool-calls` / `resp`，由主循环解释执行。
- **双 steering 轮询点**：每轮请求前轮询一次；自然停止前再轮询（steering 优先于 follow-up），排队消息以续跑而非结束会话（见 `(liii pi agent loop-queue)`）。
- **中止检查点**：`pi-aborted?`（`(liii pi ai abort)`）在主循环边界、工具批次边界、流式回调等检查点探测；已在途的流式请求由 stream 层中止。

## 事件列表

`emit` 回调接收 `(事件类型 . 参数)` 形式的事件。事件 record 定义与 JSON 编解码见 `(liii pi agent event)`；`agent_settled` 定义在 `(liii pi code event agent-settled)`。

| 事件 | 参数 | 触发时机 |
| --- | --- | --- |
| `agent_start` | - | `run-agent-loop` 启动时 |
| `turn_start` | - | 每轮开始（含 steering/follow-up 注入续跑后的新一轮） |
| `message_start` | `msg` | 每条消息上屏开始（初始消息、assistant 回复、注入消息、工具结果消息） |
| `message_update` | `usage, stream-ev` | Provider 流式响应期间 |
| `message_end` | `msg` | 每条消息上屏结束 |
| `tool_execution_start` | `id, name, args` | 单个工具调用开始执行 |
| `tool_execution_update` | `id, name, args, partial-result` | 工具流式输出（如 bash on-update） |
| `tool_execution_end` | `id, name, result, is-error, [duration-ms]` | 单个工具调用执行完成 |
| `turn_end` | `assistant-msg, tool-results` | 单轮结束（工具批次后携工具结果向量；结算时为 `#()`） |
| `agent_end` | `final-msgs, will-retry, cost, savings` | 会话结束，携完整消息历史与成本汇总 |
| `agent_settled` | `aborted?` | 会话结算完成（紧随 agent_end，TUI 依此解锁队列） |

另有**扩展事件桥**（经 config 的 `emit-extension-event` 注入，不走 `emit`）：

| 扩展事件 | 载荷 | 说明 |
| --- | --- | --- |
| `turn_start` | `((turn . N))` | 每轮开始，附轮次编号 |
| `tool_call` | `(id name tool input)` | 工具调用前；返回 `(action . block)` 可拦截，`(payload …)` 可改写入参，`(terminate . #t)` 可终止运行 |
| `tool_result` | `(id name tool input result isError)` | 工具调用后 |

## config 配置键

由上层注入的可选钩子（均为缺失时安全降级）：

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `tools` | list | 工具定义列表（默认 `()`） |
| `provider` | string | Provider 名称（默认 `"google"`） |
| `execute-tool-call` | procedure | 工具执行器 `(name . args) → tool-result`；缺失时返回占位错误结果 |
| `prepare-request` | procedure | 每次 Provider 请求前调用，`(cfg) → effective-cfg` |
| `emit-extension-event` | procedure | 扩展事件桥（turn_start / tool_call / tool_result） |
| `get-steering-messages` | procedure | steering 轮询回调，`() → list`（不得抛错，无消息返回空表） |
| `get-follow-up-messages` | procedure | follow-up 轮询回调，`() → list` |

`compaction` 参数为 alist，`compactor` 过程 `(msgs) → msgs` 接收并返回消息列表；返回非列表结果时忽略压缩。

`system-prompt` 为字符串或 `(tool-calls) → string` 回调。

## stop-reason 语义

| 值 | 含义 | 主循环行为 |
| --- | --- | --- |
| `toolUse` | 模型请求工具调用 | 执行工具后 continue 下一轮 |
| `stop` | 自然停止 | stop-check：轮询 steering/follow-up 后决定续跑或结算 |
| `length` | 输出超长截断 | 同 stop-check；结算时为未执行的工具调用补失败结果 |
| `error` | 错误 | hard-stop 直接结算 |
| `aborted` | 用户中止 | hard-stop / 循环边界直接结算，`agent_settled` 携 `#t` |

## 相关模块

| 模块 | 职责 |
| --- | --- |
| `(liii pi agent loop-queue)` | steering / follow-up 排队消息的轮询与注入 |
| `(liii pi agent tools)` | 工具调用执行、扩展拦截、结果消息构造 |
| `(liii pi agent cost)` | 成本附加（`pi-agent-attach-cost`）与会话成本汇总 |
| `(liii pi agent budget)` | 轮数/时间预算临界告警（缓存友好的静态告警块） |
| `(liii pi agent event)` | 10 种生命周期事件 record 与 JSON 编解码 |
| `(liii pi ai abort)` | 会话级中止信号（`pi-aborted?` 检查点） |
| `(liii pi ai dispatch)` | 默认 `request-fn`（`pi-request-provider-stream`） |
