# `/model` 立即生效改造规划

## 1. 目标与上游行为基准

以 `~/git/pi` 当前实现为准，而不是以 `da/switch-model` 分支为准：

- `packages/coding-agent/src/modes/interactive/interactive-mode.ts`
  - `/model` 的精确匹配和选择器最终都调用 `session.setModel(...)`。
- `packages/coding-agent/src/core/agent-session.ts`
  - `setModel` 立即更新 `agent.state.model`，同时更新会话记录和模型对应的 thinking level。
  - `_installAgentRequestProjection` 在每次请求前读取最新的 `agent.state.model/thinkingLevel`。
- `packages/agent/src/agent-loop.ts`
  - `prepareRequest` 在每一次新的 Provider 请求前执行，而不是只在 Agent run 启动时执行一次。

因此 gfcode 应对齐以下语义：

1. `/model` 返回后，当前会话的模型选择立即改变，界面立即显示 `Model: <id>` 或 `Default model: <provider>/<id>`。
2. 已经发出的 HTTP 流式请求不取消、不重放，仍由原模型完成。
3. 此后每一次新的 Agent/Provider 请求都读取最新选择，包括：
   - 工具调用完成后的续轮请求；
   - steering 注入后的请求；
   - follow-up 注入后的请求；
   - 当前 run 结束后的普通新消息。
4. 在连续执行 `A -> B -> C` 且中间尚未发起新请求时，下一次请求直接使用 C。
5. 仅执行 `/model` 不主动产生一次新请求；如果 Agent 已自然结束且没有后续消息，就直接结算。
6. thinking level 随模型切换一起生效；provider、协议、模型元数据、认证、请求头、代理及上下文窗口也必须一起切换。
7. `/model` 的现有持久化语义不变：普通模型仍写一条 `model_change`，`Ctrl+S` 仍保存默认模型，all-in-one 伪模型仍不写入物理模型的 `model_change` 条目。

### 明确不采用的做法

- **不采用 `da/switch-model` 分支的方案。** 不增加空闲时投递到 `jobs-chan` 的 `(model_change ...)` 任务。
- 不做“只同步空闲 Worker”的修复；这无法覆盖运行中工具续轮、steering 和 follow-up，且空闲时原有下一条消息载荷本就能切换模型。
- 不通过 abort、重启当前 Agent run 或重发用户消息实现切换。
- 不保留“本轮结束之后，将会切换到……”及 `agent_settled` 后才提示“已经切换到……”的延迟语义。
- 不让前台显示模型、Worker 当前配置和实际请求模型形成三套互相等待同步的状态机。

## 2. 当前根因

1. `tui/liii/pi/tui/interactive/app-events.scm` 的 `%pi-app-job-payload` 只在**新消息出队时**携带 provider/model/thinking 快照。
2. `tui/liii/pi/tui/interactive/worker.scm` 在消息开始时通过 `%worker-job-cfg` 派生一次 `job-cfg`，整个 `run-session-flow/run-agent-loop` 随后复用这份配置。
3. 运行中的 steering/follow-up 只经过独立消息通道，不经过 `%pi-app-job-payload`，所以它们产生的新请求仍使用旧模型。
4. `jobs-chan` 是串行任务通道，Agent run 执行期间 Worker 阻塞在该 run 内，无法再消费另一个任务来更新当前配置。
5. `app-model.scm`、`app-events.scm`、`footer.scm` 中的 pending-model 状态把上述限制进一步固化成了“本轮结束后才切换”的界面行为。

核心修复点必须是：**在每一次新 Provider 请求前解析最新选择，而不是再增加一个串行任务。**

## 3. 总体方案

### 3.1 独立的“最新请求选择”通道

在 TUI app 中新增独立于 `jobs-chan` 的 `request-selection-chan`，传输一次完整的选择快照：

```scheme
(provider model-id thinking-level thinking-level-explicit?)
```

要求：

- `/model` 在模型及联动 thinking level 计算完成后发布一次快照。
- `/thinking` 修改等级后也发布当前完整快照，避免它被一个较早的 `/model` 快照覆盖；这是保证 `/model` 联动 thinking 不回归所必需的配套修改。
- 通道采用 latest-wins：发布新快照时清理未消费的旧快照，Worker 消费时也排空并只应用最后一项。
- 发布不能长时间阻塞 TUI；通道关闭等异常必须给出错误提示，不能像错误分支一样静默吞掉后假装已生效。
- 普通消息的五元 job payload 暂时保留，用于新任务初始配置及旧调用兼容；它不再是运行中切换模型的机制。
- all-in-one 也发布运行时选择快照，但仍保持“不写物理模型 `model_change` 会话条目”的现有规则。

### 3.2 Worker 持有连续的有效配置

为每个 Worker 建立贯穿多个 job 的 runtime/effective-cfg 状态（可用 box/record 实现），并安装一个 `prepare-request` 回调：

1. 新普通消息到来时，仍由现有 job payload 初始化该消息的配置。
2. 每次即将发起 Provider 请求时，回调排空 `request-selection-chan`，取最后一项选择。
3. 复用现有模型配置派生逻辑，将选择应用到当前配置，并同步更新 Worker 的 effective-cfg。
4. 没有新选择时继续使用 effective-cfg，不能回退到 run 启动时的旧配置。
5. 跨 provider 时仍执行 `augment-pi-config`，确保扩展注入的 request-key/rotate-key 等逻辑同步更新。
6. 派生或认证失败走现有 Worker 错误事件与结算路径，不静默忽略。

配置派生必须覆盖：

- `provider`、`provider-api`、`model-id`、`model-meta`；
- `api-key`、`headers`、`proxy-url`；
- `supports-thinking`、`thinking-level`、`thinking-level-explicit?`；
- 当前模型的 `contextWindow`（供压缩判断及 footer usage 换算使用）。

### 3.3 Agent 在每次请求前调用准备钩子

在 Agent 层增加与 TUI 无关的通用 `prepare-request` 配置钩子：

- 从 cfg 中读取可选 procedure；未配置时完全保持现状。
- `pi-step-agent-turn` 每次调用 `request-fn` 前取得 effective-cfg。
- Provider 名称、请求配置和费用计算均使用本次 effective-cfg。
- 已开始的 `request-fn` 调用不被中断；下一次 `pi-step-agent-turn` 才读取新选择。
- Agent 层不 import TUI，也不直接感知 channel。

`code/modes/flow.scm` 的 all-in-one 适配器也要按**本次 effective-cfg** 选择，不能在 run 启动时根据初始 provider 固化普通/all-in-one 分发，否则普通模型与 all-in-one 之间运行中切换仍会走错协议。

### 3.4 移除延迟切换界面

- `/model` 无论 busy/idle 都立即更新 app 当前模型、thinking、footer 和提示卡片。
- 删除 app 的 `pending-model-switch` 和 footer 的 `pending-from`。
- 删除 `agent_settled/error` 时补发“已经切换到……”的逻辑。
- footer 不再显示“正在请求的旧模型 -> 待切换的新模型”。
- all-in-one 自身的 `all-in-one/<chain> -> 实际节点` 展示保留；它与 `/model` 的 pending 展示不是同一功能。

## 4. 生产代码文件清单

### 4.1 Agent / Code 层

#### 修改 `agent/liii/pi/agent/loop.scm`

- 在 `pi-step-agent-turn` 的请求边界调用可选 `prepare-request`。
- 用返回的 effective-cfg 读取 provider/tools、调用 `request-fn` 并执行 `pi-agent-attach-cost`。
- 未提供钩子或钩子无更新时沿用原 cfg，保持 CLI、现有测试及非交互调用兼容。
- 更新相关注释，明确“每次新请求”，避免误写成每个 job 只调用一次。

#### 修改 `code/liii/pi/code/modes/flow.scm`

- 将 `run-agent-loop-with-timeout` 中普通 Provider 与 all-in-one 的选择改为每次请求按 effective-cfg 动态判断。
- 保留现有 `probe-fn/request-fn` 测试注入口及 all-in-one 的 emit 注入。
- 保证普通模型 `A -> all-in-one -> 普通模型 B` 的后续请求分别进入正确分发路径。

#### 修改 `code/liii/pi/code/core/compaction/flow.scm`

- `pi-make-compaction-option` 创建的 compactor 在执行时同样解析最新 effective-cfg，不能一直使用创建闭包时的初始模型。
- `pi-resolve-compaction-window` 和 `pi-compact-session!` 使用同一份本次有效配置，保证切换模型后压缩阈值、摘要请求模型及认证信息一致。
- 不改变未安装 `prepare-request` 时的现有自动压缩行为，也不改变压缩条目格式。

### 4.2 TUI 状态与发布链路

#### 修改 `tui/liii/pi/tui/interactive/state.scm`

- 新增 `request-selection-chan` 字段及访问器并导出。
- 删除 `pending-model-switch` 字段、访问器和修改器。
- 如集中放置 latest-wins 发布辅助函数，也在此导出；不要在 `app-model` 与 `app-thinking` 中复制两套不同的发布规则。

#### 修改 `tui/liii/pi/tui/interactive/app.scm`

- 在 `make-pi-app` 中创建 `request-selection-chan`。
- 调整 `%make-pi-app` 的位置参数，移除 pending-model 字段并传入新 channel，避免位置参数错位。
- 启动 `pi-tui-agent-worker` 时把新 channel 传入 Worker。
- 保持 `jobs-chan` 只承担消息、落盘、统计、恢复等串行任务。

#### 修改 `tui/liii/pi/tui/interactive/app-model.scm`

- 从 `%apply-model!` 删除 busy 判断、footer pending 快照和延迟提示。
- 在 `pi-app-apply-model-ui!` 完成 provider/model/thinking 联动后，由统一出口发布完整选择快照。
- 精确引用、选择器 Enter、`Ctrl+S` 继续共用同一应用出口。
- 保留 `%record-model-change!` 的会话落盘职责，但不给它增加 Worker 配置同步职责。
- 普通模型只写一条 `session_state/model_change`；同模型重复选择不写；all-in-one 只发布运行时选择、不写该条目。
- busy 时提示也与 idle 一致：`Model: ...` / `Default model: ...`。

#### 修改 `tui/liii/pi/tui/interactive/app-thinking.scm`

- 在显式 `/thinking`、选择器和 `Shift+Tab` 的共同生效出口发布当前完整选择快照。
- 保持原有 `thinking_level_change` 落盘次数和默认等级保存逻辑不变。
- `/model` 内部自动 clamp 仍只随模型快照发布，不额外伪造一次用户 `thinking_level_change`。

#### 修改 `tui/liii/pi/tui/interactive/app-events.scm`

- 删除 `%pi-app-finish-pending-model-switch!` 及其在 `agent_settled/error` 中的调用。
- 保留队列结算、steering/follow-up 上屏及原有 `%pi-app-job-payload` 格式。
- 将“切换只对下一条消息生效”的注释改为“job 提供初始快照；每次请求前由 prepare-request 读取最新选择”。

### 4.3 Worker 与上下文窗口

#### 新增 `tui/liii/pi/tui/interactive/worker-model.scm`

把模型选择和请求前刷新的逻辑独立出来，避免继续膨胀已接近 450 行上限的 `worker.scm`：

- 移入或复用 `pi-cfg-with-thinking`、`pi-cfg-with-model`、`%worker-job-cfg` 等模型配置派生逻辑。
- 新增 runtime/effective-cfg 的创建、读取和更新辅助函数。
- 新增 `prepare-request` 构造器：排空选择通道、last-wins、派生完整配置并保存 effective-cfg。
- 保留旧二元 job（只有 msg/thinking）的兼容行为。
- `worker.scm` 可 import 后再导出原有函数名，避免现有调用与测试被迫同时改库名。

#### 修改 `tui/liii/pi/tui/interactive/worker.scm`

- 在 `pi-tui-agent-worker` 生命周期内创建并持续传递 runtime/effective-cfg，而不是每个 job 都回到初始 cfg。
- 将 `request-selection-chan` 接入普通 Agent job 的 `prepare-request`。
- 新 job 的 payload 与 channel 有竞争时，以请求边界读到的最新 channel 快照为准。
- `pi-worker-handle-job` 的非消息任务（落盘、统计、resume、reload）不得误清空当前模型选择。
- 不增加 `(model_change ...)` job 分支。
- 给事件桥提供动态上下文窗口读取方式，使运行中切模后的 `message_usage` 使用本次响应模型的窗口。

#### 修改 `tui/liii/pi/tui/interactive/worker-emit.scm`

- `make-tui-emit` 在保留“直接传数字/#f”兼容形式的同时，支持传入 context-window getter。
- `message_end` 生成 `message_usage` 时读取该响应对应的有效窗口，而不是永远使用 run 启动时的窗口。
- all-in-one `active_node` 更新实际节点窗口的现有行为继续保留；该覆盖只作用于发出它的 all-in-one 请求，后续 effective-cfg 改变时必须刷新/清除旧节点覆盖，不能污染普通模型或另一条链的 usage。
- 优先级明确为“本次 all-in-one 请求已上报的物理节点窗口 > 本次 effective-cfg 的模型窗口”。

### 4.4 Footer 清理

#### 修改 `tui/liii/pi/tui/interactive/footer.scm`

- 删除 `pending-from` 字段及 `pi-footer-pending-model`、`pi-footer-set-pending-model!`、`pi-footer-clear-pending-model!`。
- `pi-footer-set-active-node!` 删除 pending 特判，恢复只维护 all-in-one 实际节点。
- `pi-footer-set-model!` 继续立即更新 provider/model/supports/context-window。

#### 修改 `tui/liii/pi/tui/interactive/footer-model.scm`

- `pi-footer-right-part` 删除 pending-from 参数及“旧模型 -> 新模型”的双段拼接。
- 保留普通模型展示及 all-in-one 当前实际节点的 `active-node` 展示。
- 同步更新函数注释，不再把待切模描述为上游 Pi 行为。

## 5. 测试文件清单与用例

### 5.1 新增关键回归测试

#### 新增 `agent/tests/liii/pi/agent/loop/run-agent-loop-model-switch-test.scm`

用 mock request/tool executor 覆盖：

1. 第一次请求使用 A 并返回 toolUse；工具执行期间发布 B；第二次请求必须使用 B。
2. 工具期间连续发布 B、C；第二次请求只使用 C。
3. steering/follow-up 驱动的新请求读取最新模型，而不是 run 初始模型。
4. 未配置 `prepare-request` 时现有单轮和多轮行为不变。
5. 自然停止且没有后续消息时，仅切换模型不额外触发请求。

同时更新 `agent/tests/liii/pi/agent/loop/pi-step-agent-turn-test.scm`，直接断言准备钩子返回的 provider/model/config 确实传给 `request-fn` 和费用计算。

#### 新增 `tui/tests/liii/pi/tui/interactive/worker-model/pi-worker-prepare-request-test.scm`

覆盖：

- channel 为空时沿用 effective-cfg，不回退旧模型。
- 多个待消费快照只应用最后一个。
- 同 provider 切模型与跨 provider 切换都更新完整配置。
- 跨 provider 仍执行 augment；模型级 `provider-api`、认证 headers、proxy 不残留旧值。
- thinking level 与显式标志随快照更新。
- 旧二元 job 仍兼容。
- 无效模型/认证错误可观察，不被空 `catch` 吞掉。

新增对应索引：`tui/tests/liii/pi/tui/interactive/worker-model/README.md`。

#### 新增 `tui/tests/liii/pi/tui/interactive/worker/pi-worker-model-switch-test.scm`

通过真实 Worker 配置构造 + mock Provider 请求验证完整链路：

- A 请求 -> 工具执行 -> `/model` 选择 B -> B 续轮请求。
- A 请求 -> steering + B -> B 请求。
- A 请求 -> follow-up + B -> B 请求。
- 普通模型与 all-in-one 双向切换进入各自正确适配器。
- run 结束后下一条普通消息继续使用最后选择，不发生 A/B 回摆。

### 5.2 修改现有测试

- `code/tests/liii/pi/code/modes/flow/run-agent-loop-with-timeout-test.scm`
  - 增加 effective-cfg 动态选择普通/all-in-one 分发的覆盖，保留现有 all-in-one 探活用例。
- `code/tests/liii/pi/code/core/compaction/flow/pi-make-compaction-option-test.scm`
  - 验证 compactor 执行时重新读取 effective-cfg，压缩窗口与摘要请求不继续使用初始模型。
- `tui/tests/liii/pi/tui/interactive/app-model/pi-app-submit-model-bang-test.scm`
  - 将 busy 场景的“本轮结束后切换”断言改为立即 `Model: ...`、立即显示新 footer、无 pending 状态、settle 后不追加二次提示。
  - 保留连续切换与切回原模型用例，但以下一次请求的最终选择为准。
- `tui/tests/liii/pi/tui/interactive/app-model/pi-app-model-session-state-test.scm`
  - 继续断言普通模型只产生一条 `session_state/model_change`。
  - 明确断言 `jobs-chan` 中**没有**额外的 `(model_change ...)` 任务。
  - 从独立选择 channel 验证运行时快照；all-in-one 有运行时快照但无会话状态条目。
- `tui/tests/liii/pi/tui/interactive/app-thinking/pi-app-submit-thinking-bang-test.scm`
  - 验证显式修改 thinking 后发布的是当前 provider/model 的完整最新快照。
- `tui/tests/liii/pi/tui/interactive/worker/pi-worker-steering-wiring-test.scm`
  - 保留现有消息注入测试，并补充“消息与模型选择同时到达时二者都生效”的集成断言。
- `tui/tests/liii/pi/tui/interactive/worker/pi-cfg-with-model-test.scm`
  - 保留现有协议、headers、凭证回归；若函数移到新库，验证 `worker.scm` 的兼容再导出或直接把 import 调整为 `worker-model.scm`。
- `tui/tests/liii/pi/tui/interactive/worker/%worker-job-cfg-test.scm`
  - 保留旧 job 兼容覆盖，并补充新任务不会覆盖更新的 channel 选择。
- `tui/tests/liii/pi/tui/interactive/worker-emit/make-tui-emit-context-test.scm`
  - 覆盖数字窗口的兼容形式、动态 getter 切窗，以及 all-in-one 实际节点窗口优先级。
- `tui/tests/liii/pi/tui/interactive/footer-model/pi-footer-right-part-test.scm`
  - 删除 pending-from 双段展示断言，保留普通与 all-in-one active-node 展示。
- `tui/tests/liii/pi/tui/interactive/state/README.md`、相关模块 README
  - 更新函数索引，移除 pending-model API，加入 request-selection API；新增模块按仓库约定补索引。

### 5.3 删除只服务于错误延迟语义的测试

- `tui/tests/liii/pi/tui/interactive/state/pi-app-pending-model-switch-test.scm`
- `tui/tests/liii/pi/tui/interactive/state/%pi-app-pending-model-switch-set-bang-test.scm`
- `tui/tests/liii/pi/tui/interactive/footer/pi-footer-pending-model-test.scm`
- `tui/tests/liii/pi/tui/interactive/footer/pi-footer-set-pending-model-bang-test.scm`
- `tui/tests/liii/pi/tui/interactive/footer/pi-footer-clear-pending-model-bang-test.scm`

新增对应的 request-selection channel 状态测试，而不是简单减少覆盖率。

## 6. 实施顺序

1. 先给 Agent `prepare-request` 和 Worker 请求前刷新写回归测试，复现“工具续轮仍用旧模型”。
2. 实现 `worker-model.scm`、Worker effective-cfg 和动态 all-in-one 分发，使底层测试通过。
3. 接入 TUI 独立选择 channel，再改 `/model` 与 `/thinking` 发布逻辑。
4. 删除 pending-model 状态、延迟卡片和 footer 双段展示。
5. 接入动态 context-window，补齐普通/all-in-one、持久化和错误路径测试。
6. 最后清理注释、函数索引和兼容导出，检查文件行数与格式。

## 7. 验收标准与命令

行为验收：

- 在 A 的流式响应期间切到 B：A 的当前响应不被中断；若产生工具续轮，下一次请求明确发送到 B。
- 在工具执行期间执行 `A -> B -> C`：下一次请求只发送到 C。
- steering/follow-up 与普通新消息均不再使用 run 启动时的旧模型。
- footer 与提示立即显示当前选择，无“本轮结束后”提示，无 settle 后二次切换提示。
- provider-api、认证 headers、proxy、thinking、contextWindow 与目标模型一致；会话文件仍保持原有条目格式和数量。

完成后执行：

```bash
gf test agent/tests/liii
gf test code/tests/liii
gf test tui/tests/liii

gf fmt --check agent
gf fmt --check code
gf fmt --check tui
gf check
```

必要时再运行相关 E2E：

```bash
gf test code/tests/e2e
```

全部测试和静态检查通过，且新增测试能够证明“当前 HTTP 请求不变、下一次 Agent 请求立即使用新模型”，才视为完成。
