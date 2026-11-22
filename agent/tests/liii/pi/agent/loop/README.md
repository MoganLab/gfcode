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

## 完整流程

`run-agent-loop` 是一个尾递归状态机，循环状态为 `(msgs turn last-tool-calls)`。整体流程如下：

```
run-agent-loop(config, initial-messages, system-prompt, emit, ...)
│
├─ emit('agent_start)
├─ emit('turn_start)                        ;; 第 1 轮
├─ emit-initial? 时逐条 emit 初始消息的 message_start / message_end
├─ 计算 deadline-sec = now + session-timeout（仅 session-timeout > 0 时）
│
└─ loop(msgs, turn, last-tool-calls)
   │
   ├─【前置检查，每轮循环开始处】
   │  ├─ (pi-aborted?)                     → emit agent_end(aborted) + agent_settled(#t)，返回 msgs
   │  ├─ session-timeout < 0               → pi-emit-agent-error(会话超时错误)
   │  ├─ 超过 deadline-sec                 → pi-emit-agent-error(会话超时错误)
   │  └─ turn >= max-turns（> 0 时）       → pi-emit-agent-error(轮数上限错误)
   │
   └─ %run-agent-turn —— 执行单轮：
      │
      ├─ 1. 扩展桥 ext-emit('turn_start ((turn . N)))   ;; 仅注入了 emit-extension-event 时
      ├─ 2. pi-maybe-compact                            ;; 上下文压缩（compactor 钩子）
      ├─ 3. %maybe-inject-steering!                     ;; steering 轮询点 ①：请求前注入排队消息
      │     （有消息则转 user 消息追加，并逐条 emit message_start / message_end）
      ├─ 4. rem-sec = deadline-sec - now
      ├─ 5. pi-resolve-turn-system-prompt               ;; 系统提示词 + 预算临界告警
      │
      ├─ 6. pi-step-agent-turn —— 单次 Provider 请求：
      │     ├─ %resolve-effective-cfg                   ;; prepare-request 钩子：每次请求前
      │     │  解析最新配置（TUI 运行中切模在此生效）；未配置时沿用原 config
      │     ├─ 从 eff-cfg 取 tools / provider
      │     ├─ request-fn(provider, eff-cfg, msgs, sys-prompt, tools, on-stream-ev, timeout)
      │     │  └─ 流式回调期间 emit('message_update usage ev)
      │     ├─ pi-agent-attach-cost                     ;; 附加成本信息
      │     ├─ emit('message_start resp) + emit('message_end resp)
      │     └─ 返回 (new-msgs, stop-reason, tool-calls, resp)
      │
      └─ 7. 按 stop-reason 分派决策：
         │
         ├─ "toolUse" → pi-handle-tool-use
         │  └─ pi-execute-tool-calls-with-status 逐个执行工具调用：
         │     ├─ emit('tool_execution_start id name args)
         │     ├─ 扩展桥 'tool_call 事件（可返回 block/terminate/payload 拦截或改写）
         │     ├─ 调用 config 的 execute-tool-call 执行器（bash 支持 :on-update 流式更新）
         │     │  └─ 流式期间 emit('tool_execution_update id name args partial-result)
         │     ├─ emit('tool_execution_end id name result is-error [duration-ms])
         │     ├─ emit 工具结果消息的 message_start / message_end
         │     │  ;; 批次语义：前一个工具 terminate 则后续跳过；用户中止则跳过剩余
         │     └─ pi-notify-turn-end：emit('turn_end resp tool-results)
         │  ├─ 未终止 → 决策 continue → emit('turn_start) → loop(turn+1)
         │  └─ 工具批次终止 → 决策 stop-check（stop-reason 视为 "stop"）
         │
         ├─ "error" / "aborted" → 决策 hard-stop
         │  └─ pi-finish-agent-turn：结算（见下）
         │
         └─ 其他（"stop" / "length" 等）→ 决策 stop-check（自然停止）
            └─ %stop-or-continue：
               ├─ steering 轮询点 ②：优先 get-steering-messages，其次
               │  get-follow-up-messages；任一有消息 → 注入 user 消息 +
               │  emit('turn_start) → loop(next-msgs, turn+1) 续跑
               └─ 两队列皆空 → pi-finish-agent-turn 结算

pi-finish-agent-turn 结算路径：
  ├─ stop-reason 为 "length" 且有 tool-calls 时
  │  追加 pi-fail-tool-calls-length 的跳过失败结果消息
  ├─ pi-notify-turn-end：emit('turn_end resp #())
  └─ pi-emit-agent-end：
     ├─ 汇总会话成本 pi-agent-session-cost-summary
     ├─ emit('agent_end final-msgs #f cost savings)
     └─ emit('agent_settled aborted?)

pi-emit-agent-error 错误路径（中止/超时/轮数上限）：
  ├─ 构造 stop-reason 为 "error" 的 assistant 错误消息并附加成本
  ├─ emit('turn_start) + message_start/message_end + turn_end(resp, #())
  └─ pi-emit-agent-end：agent_end + agent_settled(#f)
```

### 关键设计点

- **prepare-request 钩子**：`pi-step-agent-turn` 在每次新的 Provider 请求前调用 cfg 中可选的 `prepare-request` 过程排空选择通道并返回本次有效的 effective-cfg，使运行中切模立即对下一次请求生效；未配置时直接沿用传入 config，保持 CLI 与非交互调用兼容。已开始的请求不被中断，下一次请求才再次读取。
- **系统提示词缓存友好**：非临界时系统提示词必须与 base 字节级一致，只有轮数/时间预算临界时才拼接一次静态 `<budget_warning>` 告警块（不含逐轮变化的数字），避免逐轮变化击穿供应商前缀缓存（见 `(liii pi agent budget)`）。
- **steering / follow-up 双轮询点**：每轮请求前轮询 steering（`%maybe-inject-steering!`）；自然停止前先 steering 后 follow-up（`%natural-stop-continue`），任一有排队消息则以新消息续跑下一轮而非结束会话（见 `(liii pi agent loop-queue)`）。
- **中止检查点**：`pi-aborted?`（`(liii pi ai abort)`）在主循环边界、工具批次边界、流式回调等检查点探测；中止后不再发起新一轮请求，已在途的流式请求由 stream 层中止。
- **决策状态机**：`%run-agent-turn` 返回决策 alist（`continue` / `hard-stop` / `stop-check`），统一携带 `msgs` / `stop-reason` / `tool-calls` / `resp` 四个键，由主循环解释执行。

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
