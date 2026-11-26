---

name: tmux
description: 使用 tmux（包括 Windows 上的 psmux）启动和控制交互式程序，发送消息、捕获输出并恢复会话。用户要求在 tmux 中运行 gf pi、与已有会话交互、观察终端输出，或遇到 no server running、会话消失等问题时使用。
---

# tmux

通过 tmux 操作交互式程序。始终检查会话是否存活、观察命令输出，并避免在状态未知时重复发送消息。

## 基本约定

- 使用固定的描述性会话名，例如 `gf-pi-hello`，并在不同工具调用中重复使用它。
- 将 `$SESSION` 等变量视为单个 shell 调用的局部变量；不要假设下一次调用仍保留这些变量。
- 每次 `send-keys` 之前和 `capture-pane` 之前都检查会话；失败时报告实际错误，不要声称操作成功。
- 不要通过杀掉服务端、使用 `kill-server` 或清理所有会话来解决单个会话的问题。
- 未经用户同意，不要关闭用户已有的会话；仅清理本任务创建且不再需要的会话。
- 向已运行的会话发消息时，**文本与 `Enter` 必须拆成两次 `send-keys`，中间 `sleep 1`**；
  合并成 `send-keys "$MSG" Enter` 在 psmux 下不可靠（详见第 3 节）。首条消息优先用启动参数提交。

## 1\. 检查环境与会话

```bash
command -v tmux
tmux -V
tmux list-sessions
```

`tmux list-sessions` 在没有服务端时可能返回非零，这不一定是 tmux 安装故障。Windows 环境中，错误前缀可能显示为 `psmux`，仍按 tmux 会话处理。

检查目标会话：

```bash
SESSION='gf-pi-hello'
tmux has-session -t "$SESSION" 2>/dev/null
```

只有该命令返回成功，才能继续向该会话发送按键或读取窗格。

## 2\. 启动交互式程序

启动程序，并在程序退出后保留 shell，便于读取错误和退出状态。

### 在 Windows / psmux 下用 `Start-Process` 启动（重要）

psmux（Windows 上的 tmux）服务端设计为无限存活、无超时，但**在本 harness（gf 的
bash 工具）里会被反复清掉**，原因见下文“psmux 服务端为什么会被清理”。直接在 bash 里
`tmux new-session -d ...` 会让 psmux 服务端成为当前 bash 的子进程，几乎一定在下一次
工具调用结束时被连坐终止。改用 PowerShell 的 `Start-Process -WindowStyle Hidden`
启动，让 psmux 服务端尽量脱离当前 bash 的进程树/Job，能显著延长存活时间。

```bash
SESSION='gf-pi-hello'
SESSION_DIR="$(mktemp -d -t gf-pi-XXXXXX)"          # 隔离会话存储，见下文
SD_WIN="$(cygpath -w "$SESSION_DIR" 2>/dev/null || echo "$SESSION_DIR")"  # psmux 需要 Windows 风格路径

if tmux has-session -t "$SESSION" 2>/dev/null; then
  printf 'Session already exists: %s\n' "$SESSION"
else
  powershell.exe -NoProfile -Command "Start-Process psmux.exe -ArgumentList 'new-session','-d','-s','$SESSION','--','gf','pi','--session-dir','$SD_WIN' -WindowStyle Hidden"
fi

sleep 3
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -100
```

如需启动时直接提交第一条消息，把消息追加到 `--` 之后：

```bash
powershell.exe -NoProfile -Command "Start-Process psmux.exe -ArgumentList 'new-session','-d','-s','$SESSION','--','gf','pi','--session-dir','$SD_WIN','hello' -WindowStyle Hidden"
```

启动参数消息**最可靠**——它绕过 TUI 输入框直接作为初始用户消息，不存在 `Enter` 被吞的问题。需要发首条消息时优先用启动参数；只有向**已运行**的会话追加消息时才用第 3 节的两次 `send-keys`。显式指定要运行的程序，不要假设新窗格默认运行 `gf pi`。

注意：`Start-Process` 仍**不能保证**服务端永久存活（Job 限制下偶发 breakaway 失败
时仍会被清理），因此务必配合下文的隔离 `--session-dir`，以便服务端被清后能用
`--continue` 精确恢复子对话。

### 为什么用 `--session-dir` 隔离会话存储

`gf pi` 把对话以 `*.jsonl` 落盘到“按 cwd 命名的会话目录”下（默认
`~/.gf/agent/sessions/<cwd 编码>`）。`--continue` 在该目录里按**文件名（ISO
时间戳前缀）字典序**取最大一个作为“最新会话”恢复，它**不读取 mtime，也不校验
哪个进程正在使用**。

后果：当外层 agent（调用本 skill 的那个 pi）和 tmux 里的子 `gf pi` 处于**同一
cwd** 时，外层 agent 自身的对话文件往往是字典序最大的那一个。此时子会话里执行
`gf pi --continue` 会恢复**外层 agent 的对话**，而不是被 psmux 清掉的子对话。
表现为窗格里出现外层对话内容（例如“tmux skill 已加载……”），而非子对话历史。

因此：**为每个 tmux 子对话指定一个独立的 `--session-dir`**（例如 `mktemp -d`），
让子对话在隔离目录里读写，`--continue` 也只在该隔离目录里找“最新”，与外层对话、
与其它子对话互不污染。把该目录路径记录下来，供后续恢复复用。

- 不要复用项目本身的会话目录或默认目录。
- `--no-session` 可彻底关闭落盘，但那样 `--continue` 就无法恢复该对话了，仅适用于
  一次性、不需要恢复的运行。

## 3\. 发送消息并观察输出

`gf pi` 兼容 Pi 的 TUI 约定，**提交键是 `Enter`**（普通提交）；模型正在工作时按 Enter 提交的消息会作为
“steering message”排队，等当前工具调用结束后才处理。所以 `Enter` 一定能送达，但未必立即出现在对话区。

### 重要：必须把文本和 Enter 拆成两次 `send-keys`

在本环境的 psmux 下，`tmux send-keys -t "$SESSION" "$MESSAGE" Enter`（文本与 Enter 在同一条命令里）
**不可靠**：psmux 几乎同时把文本和 `Enter` 注入伪终端，`Enter` 可能在 TUI 还没消费完文本时就到达，
导致 `Enter` 被吞掉，消息一直停在输入框、jsonl 无记录（实测多次复现）。

可靠做法：先单独输入文本，**`sleep 1`** 让 TUI 渲染并消费输入，再单独发 `Enter`。中间的 `sleep 1` 是经验阈值；
`sleep 0.5` 实测仍偶发失败，不要更短。

```bash
SESSION='gf-pi-hello'
MESSAGE='world'

tmux has-session -t "$SESSION" 2>/dev/null || {
  printf 'Session is unavailable: %s\n' "$SESSION" >&2
  exit 1
}

tmux capture-pane -p -t "$SESSION" -S -100          # 发送前快照

tmux send-keys -t "$SESSION" "$MESSAGE"            # 1) 先输入文本
sleep 1                                            #    等 TUI 渲染（不要省略）
tmux send-keys -t "$SESSION" Enter                 # 2) 再单独提交
sleep 5                                            #    等模型开始回复
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -150
```

- 不要写 `send-keys "$MESSAGE" Enter` 合并成一条；文本与 Enter 必须分两次 `send-keys`，中间 `sleep 1`。
- 若输入框可能有残留文本（例如上一条未提交、或刚恢复会话），先 `send-keys C-c` 清空再输入，更稳。
- 不要模拟粘贴多行文本；单行消息一次提交。多行内容改用 `--continue <message>` 启动参数或拆成多条。
- 将消息作为单个参数传递，避免 shell 拆分；消息含敏感信息时避免在日志和最终回复中复述。

### 如何判断消息是否真正送达

`Enter` 已按下、屏幕输入框清空、**不等于**消息已提交。尤其模型正在 `Working` 时，消息会排队，
屏幕不会立即显示。判断是否真正送达看**隔离目录里的 jsonl**，而非屏幕底部：

```bash
SESSION_DIR='/tmp/gf-pi-xxxxxx'                  # 与启动时同一个隔离目录
rg '"role":"user"' "$SESSION_DIR"/*.jsonl | tail -5
```

- 看到新增的 `"role":"user"` 且 `"content"` 是该消息，才算真正送达。
- jsonl 仍只有旧消息、且输入框已被清空，可能是消息在排队（模型工作时）——继续轮询，不要重发。
- jsonl 仍只有旧消息、且输入框里还停着该文本，是 `Enter` 被吞了——用 `C-c` 清空后重试拆开的两次 `send-keys`。
- 状态未知时不要自动重发，避免模型收到重复请求。

### 观察回复

- 使用 `-S -100` 或更大的负数读取滚动历史；不要只根据屏幕底部判断回复状态。
- 发送成功不等于模型已回复。等待后重新捕获，必要时每隔 5–10 秒轮询。
- 若看到消息仍在输入区、明显的转义序列或未提交的文本，先捕获完整窗格，不要盲目再次按 Enter。

需要连续观察时，使用带会话检查和次数上限的轮询：

```bash
SESSION='gf-pi-hello'

for attempt in 1 2 3 4 5 6; do
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    printf 'Session disappeared while waiting: %s\n' "$SESSION" >&2
    exit 1
  fi

  printf '\n--- poll %s ---\n' "$attempt"
  tmux capture-pane -p -t "$SESSION" -S -100
  sleep 5
done
```

需要连续观察时，使用带会话检查和次数上限的轮询：

```bash
SESSION='gf-pi-hello'

for attempt in 1 2 3 4 5 6; do
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    printf 'Session disappeared while waiting: %s\n' "$SESSION" >&2
    exit 1
  fi

  printf '\n--- poll %s ---\n' "$attempt"
  tmux capture-pane -p -t "$SESSION" -S -100
  sleep 5
done
```

## 4\. 处理会话消失与 `no server running`

典型错误：

```text
psmux: no server running on session 'gf-pi-hello'
```

或：

```text
can't find session: gf-pi-hello
```

这些错误说明**执行当前命令时**目标会话或服务端不可用，不能据此判断之前的消息是否送达，
也不能据此断定回复失败。

### psmux 服务端为什么会被清理

psmux 服务端本身**没有空闲超时**，设计为一直存活到显式 `kill-server` 或系统重启；
会话或 pane 进程退出也不会结束服务端。所以 `no server running` 几乎都不是 psmux
自身超时或崩溃，而是被**外部终止**。在本环境里，真因是：

- 本 harness（gf 的 bash 工具）为每次工具调用新建一个 bash 子进程来执行命令，调用
  **结束时回收该 bash 及其所有后代进程**（Windows Job Object 连坐）。
- 直接在 bash 里 `tmux new-session -d ...` 时，psmux 服务端是该 bash 的“孙进程”，
  与当前调用同属一个 Job，于是随调用结束被一起终止。
- 用 `Start-Process -WindowStyle Hidden` 启动能让 psmux 服务端尽量 breakaway 出
  当前 Job，显著延长存活（实测可跨多次工具调用）；但 Job 若未设
  `JOB_OBJECT_LIMIT_BREAKAWAY_OK`，breakaway 会被拒绝，仍偶发被清。
- 这是 harness 与 psmux 在 Windows 进程生命周期上的不兼容，**不是 psmux 的 bug 或
  可配置项**，无法仅靠 psmux 配置根除。

### 如何确认是不是这种清理

排查时看 psmux 状态目录 `~/.psmux`：

- `crash.log` 不存在（存在才是 psmux 自身崩溃，会带 panic + backtrace）。
- `instances/<session>` 记录在册会话、`killed/<session>` 记录被清理的会话；`killed/`
  **目录**的 mtime 更新而 `killed/<session>` **文件** mtime 未变，往往是被外部
  `TerminateProcess` 强杀（psmux 信号处理来不及写记录）。
- `server-startup.log` 记录的是首次 spawn shell 失败（如 `default-shell` 路径不存在），
  与本现象无关。

### 处理步骤

1. 用 `tmux list-sessions` 确认当前状态；记录该命令自身的错误。
2. 若会话仍在，直接捕获输出，不要重建会话或重发消息。
3. 若会话消失，先查隔离目录的 jsonl（`rg '"role":"user"' "$SESSION_DIR"/*.jsonl`），
   判断最后一条消息是否真正落盘。只有 jsonl **没有**该消息时才需要重发；若已落盘，
   用 `--continue --session-dir <隔离目录>` 恢复即可看到模型回复，不要重发。
4. 同时检查最后一份快照是否显示进程退出、错误或仍停在输入框的未提交文本。
5. 状态未知时不要自动重发消息，避免模型收到重复请求。
6. 需要重启并继续**同一子对话**时，用启动时保存的隔离 `--session-dir` 恢复，
   而不是裸用 `gf pi --continue`，且仍用 `Start-Process` 启动以延长存活：

```bash
SESSION='gf-pi-hello'
SESSION_DIR='/tmp/gf-pi-xxxxxx'                          # 与启动时同一个隔离目录
SD_WIN="$(cygpath -w "$SESSION_DIR" 2>/dev/null || echo "$SESSION_DIR")"

powershell.exe -NoProfile -Command "Start-Process psmux.exe -ArgumentList 'new-session','-d','-s','$SESSION','--','gf','pi','--continue','--session-dir','$SD_WIN','world' -WindowStyle Hidden"
sleep 5
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -150
```

### 关于 `--continue` 的恢复目标

`--continue` 恢复的是“会话目录内文件名字典序最大的 `*.jsonl`”，**不**一定是被清掉
的那一轮子对话。当外层 agent 与子 `gf pi` 同 cwd 时，外层对话往往是“最大”的那个，
裸 `gf pi --continue` 会把外层对话当成恢复目标（窗格里出现外层对话内容就是信号）。
始终带上 `--session-dir` 指向隔离目录，才能精确恢复本子对话。

- `--continue <message>`：仅在明确需要把该消息作为恢复后的下一条用户消息时才附加；
  只想查看旧会话时不要附加消息。
- 需要从多个历史会话里挑选时，用 `gf pi --resume`（弹出会话选择器），或在隔离目录里
  手动指定 `--session-file <path>`。
- `--continue` 恢复的是 gfcode 的对话记录，不会恢复已经退出的 tmux 服务端。

即便用了 `Start-Process`，服务端仍可能被宿主/harness 偶发清理。保留 gfcode 会话
（隔离目录里的 jsonl）用于恢复，并向用户说明无法保证 tmux 会话持续存活。不要承诺会话
仍在，除非刚刚通过 `has-session` 验证。

## 5\. 汇报与清理

汇报时包含：

- 实际使用的 tmux 会话名；
- 已提交的用户消息，以及每条是否已确认落盘（用 jsonl 核对，而非仅凭屏幕）；
- 从 `capture-pane` 观察到的关键输出；
- 当前会话状态，以及是否发生过退出或恢复。

仅在用户要求或任务完成后确需清理时，删除本任务创建的会话：

```bash
SESSION='gf-pi-hello'
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux kill-session -t "$SESSION"
fi
```

保留会话时，可提供人工连接命令：

```bash
tmux attach -t gf-pi-hello
```
