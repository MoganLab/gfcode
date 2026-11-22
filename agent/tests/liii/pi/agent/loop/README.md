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

上述"思考 → 行动 → 观察"的完整循环对应代码中的**一个 Turn**（轮次）：`turn_start` 事件开始，依次完成模型请求、工具执行与结果回填，最后以携工具结果的 `turn_end` 事件收尾；下一轮 Turn 从新的思考开始。事件流为：

```
turn_start
  message_start / message_end            assistant 回复（思考）
  tool_execution_start / update / end   工具执行（行动）
  message_start / message_end            toolResult 上屏（观察）
turn_end（携工具结果向量）
```

与静态的"先规划后执行"相比，ReAct 的优势在于每一步行动都基于最新观察：跑了个测试发现失败，下一轮思考就针对失败原因调整。是否结束也由思考阶段判定：模型认为还需要干活就返回 `toolUse`（继续循环），认为任务完成就返回 `stop`（自然停止）。`run-agent-loop` 就是驱动这个循环的状态机，一次调用对应 Agent 处理一个任务的完整过程。循环期间用户并非只能等待：

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
┌───────────────── 一轮（Turn）────────────────┐
│ ① 前置检查：用户中止？超时？轮数耗尽？        │
│ ② 准备：压缩上下文 / 注入 steering / 系统提示 │
│ ③ 思考：请求模型，流式得到回复                │
│    ├─ 回复要求调工具（toolUse）               │
│    │    └─ ④ 行动+观察：执行工具、回填结果 ──┐│
│    │        未被终止：回到 ② 下一轮 ◄────────┘│
│    └─ 回复即最终答复（stop 等）               │
└──────────────────────────────────────────────┘
   │
   ▼
自然停止？──是──► 用户还有排队消息？──是──► 注入续跑（回到下一轮）
   │                    └──否──► 结算
   └──否（错误/中止）──► 错误结算
   │
   ▼
结算：轮次收尾 → 会话收尾（成本汇总）→ 完成通知，返回最终消息历史
```

### 1. 启动

会话开始，界面收到开始信号，首轮开场；历史消息（如会话恢复时的旧消息）逐条上屏。若设置了会话总时长限制，则记下截止时间。

### 2. 每轮前置检查

每轮开始处依次检查三件事：用户是否按了中止（是则立即结束，已有成果保留）、会话是否超时、轮数是否耗尽（后两者以错误结算）。全部通过才进入本轮。

### 3. 单轮准备

发起模型请求前做三件事：

1. **压缩上下文**：历史过长时自动压缩旧消息，避免超出模型窗口
2. **注入引导**：用户趁 Agent 工作时新发的话，此刻以普通用户消息身份加入对话，实时改变 Agent 方向
3. **解析系统提示**：拼装本轮系统提示词；仅当轮数或时间预算快耗尽时，才在末尾附一段固定措辞的告警，提醒模型尽快收尾（措辞固定是为了不破坏供应商的提示词缓存）

### 4. 思考：请求模型

先解析"当前生效配置"（用户运行中切换的模型在此生效），然后流式请求模型，界面实时增量渲染。回复完成后上屏，并从回复中读出两个关键信息：模型想调用哪些工具（行动清单），以及模型为什么停下（停止原因，决定循环走向）。

### 5. 行动与观察：执行工具

逐个执行模型请求的工具调用。每个工具开始、结束（含耗时）、以及 bash 这类工具的增量输出都会实时上报界面；执行前还有一道扩展拦检（可拦截调用、改写参数、或强制终止本次运行）。工具结果包装成结果消息回填对话历史，这就是"观察"。

批次规则：前一个工具要求终止运行、或用户中途中止时，同批剩余调用直接跳过并补上"已跳过"结果。本批未终止则直接进入下一轮；被终止则视为自然停止，交给下一步裁决。

### 6. 停止决策

模型认为任务完成而自然停止时，再给用户最后一次机会：先查用户中途追加的引导消息，再查排队的后续任务，任一有则注入并自动续跑下一轮；都没有才真正结算。这保证 Agent 即将停下时用户排队的消息不会丢，而是自动接续执行。

### 谁决定循环是否结束

"是否结束"的信号主要由模型在思考时给出，但判定分散在三处，后一处可推翻前一处：

| 判定处 | 谁说了算 | 结果 |
| --- | --- | --- |
| 思考阶段 | 模型停止原因：还要用工具 → 继续；给出最终答复 → 完成 | 首次判定 |
| 行动阶段 | 某个工具要求终止，或用户中止 | 推翻"继续"：即使模型还想干活也强制停止 |
| 停止决策阶段 | 用户排队消息（引导 / 后续任务） | 推翻"结束"：注入消息续跑下一轮 |

此外每轮开头的中止 / 超时 / 轮数上限检查不经过思考阶段，直接强制结束。

### 7. 结算

无论哪种方式结束，最后都走同一条收尾路：

- **正常结算**：若模型因输出超长被截断，先为未执行的工具调用补上失败结果，保证对话历史完整；然后本轮收尾 → 会话收尾（附带整个会话的成本汇总）→ 完成通知
- **错误结算**（中止 / 超时 / 轮数耗尽 / 请求出错）：生成一条说明原因的错误消息补入历史，随后同样以会话收尾和完成通知告终；用户中止时完成通知会标明"因中止而结算"，界面据此解锁输入

结算后返回完整的最终消息历史，由上层落盘为会话文件。

### 关键设计点

- **运行中切模立即生效**：每次模型请求前重新解析当前生效配置，正在进行的请求不受影响，下一次请求即用新模型。
- **提示词缓存友好**：系统提示词非临界时字节级稳定，仅预算临界时附加一次固定措辞的告警，最多让供应商的前缀缓存失效一次。
- **停止前必查队列**：每轮请求前查一次引导队列；自然停止前再查一次（引导优先于后续任务），排队消息以续跑而非结束会话。
- **多检查点可中止**：主循环边界、工具批次边界、流式回调中都可探测中止信号，用户按 ESC 后既不丢已生成的回复，也不会发起无谓的新请求。

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
