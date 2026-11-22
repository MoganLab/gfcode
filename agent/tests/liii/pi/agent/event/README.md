# (liii pi agent event) 模块函数索引

`(liii pi agent event)` 对应 `@earendil-works/pi` 的 `packages/agent` 事件模型，提供 10 种 Agent 生命周期事件的 record 定义、谓词、类型查询及 JSON 编解码接口。

使用时导入：

```scheme
(import (liii pi agent event))
```

## 1. 事件列表

事件由 Agent 主循环（`(liii pi agent loop)`，见 `gf doc liii/pi/agent/loop`）通过 `emit` 回调派发，`emit` 接收 `(事件类型 . 参数)` 形式。按会话时间顺序：

| 事件 | 参数 | 触发时机 |
| --- | --- | --- |
| `agent_start` | - | 会话启动时（一次会话仅一次） |
| `turn_start` | - | 每轮开始（含引导/后续消息注入续跑后的新一轮） |
| `message_start` | `msg` | 每条消息上屏开始（初始消息、assistant 回复、注入消息、工具结果消息） |
| `message_update` | `usage, stream-ev` | Provider 流式响应期间 |
| `message_end` | `msg` | 每条消息上屏结束 |
| `tool_execution_start` | `id, name, args` | 单个工具调用开始执行 |
| `tool_execution_update` | `id, name, args, partial-result` | 工具流式输出（如 bash 的增量输出） |
| `tool_execution_end` | `id, name, result, is-error, [duration-ms]` | 单个工具调用执行完成（含耗时） |
| `turn_end` | `assistant-msg, tool-results` | 单轮结束（工具批次后携工具结果向量；自然停止结算时为 `#()`） |
| `agent_end` | `final-msgs, will-retry, cost, savings` | 会话结束，携完整消息历史与成本汇总 |
| `agent_settled` | `aborted?` | 会话结算完成（紧随 agent_end；用户中止时携 `#t`，界面据此解锁输入） |

一次典型多轮会话的事件序列：

```
agent_start
  turn_start → message_start/update/end（回复）→ tool_execution_start/update/end
    → message_start/end（工具结果）→ turn_end          ← 工具轮，重复 N 次
  turn_start → message_start/update/end（最终答复）→ turn_end
agent_end → agent_settled
```

## 2. 扩展事件桥

另一组事件经 config 的 `emit-extension-event` 注入（不走 `emit`），用于扩展拦截与审计：

| 扩展事件 | 载荷 | 说明 |
| --- | --- | --- |
| `turn_start` | `((turn . N))` | 每轮开始，附轮次编号 |
| `tool_call` | `(id name tool input)` | 工具调用前；返回 `(action . block)` 可拦截，`(payload …)` 可改写入参，`(terminate . #t)` 可终止运行 |
| `tool_result` | `(id name tool input result isError)` | 工具调用后 |

`agent_settled` 的 record 定义在 `(liii pi code event agent-settled)`；包含它的完整会话事件（含 session 头事件）编解码见 `gf doc liii/pi/code/event`。

## 3. 函数分类索引

### 事件判定与类型
- `pi-agent-event?` - 判断对象是否为任一 Agent 生命周期事件
- `pi-agent-event-type` - 返回事件类型关键字

### JSON 编解码
- `pi-agent-event->json` - 事件对象序列化为 JSON 结构
- `json->pi-agent-event` - JSON 结构反序列化为事件对象
- `pi-agent-event-normalize-json` - 递归归一化嵌套的消息/块/工具结果为可序列化结构

### 各事件构造与访问
见各子模块文档（agent-start / turn-start / message-start / message-update / message-end / tool-execution-start / tool-execution-update / tool-execution-end / turn-end / agent-end）。
