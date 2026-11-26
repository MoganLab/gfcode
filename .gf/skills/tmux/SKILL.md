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

## 1. 检查环境与会话

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

## 2. 启动交互式程序

启动程序，并在程序退出后保留 shell，便于读取错误和退出状态：

```bash
SESSION='gf-pi-hello'

if tmux has-session -t "$SESSION" 2>/dev/null; then
  printf 'Session already exists: %s\n' "$SESSION"
else
  tmux new-session -d -s "$SESSION" \
    'gf pi; status=$?; printf "\n[gf pi exited: %s]\n" "$status"; exec bash'
fi

sleep 2
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -100
```

如果用户要求启动时直接提交第一条消息，可将 `gf pi` 替换为：

```bash
gf pi hello
```

启动参数消息通常比界面尚未初始化时立即 `send-keys` 更可靠。显式指定要运行的程序，不要假设新窗格默认运行 `gf pi`。

## 3. 发送消息并观察输出

发送前捕获一次快照。它用于判断消息是否已提交，以及后续输出是否确实发生变化：

```bash
SESSION='gf-pi-hello'
MESSAGE='world'

tmux has-session -t "$SESSION" 2>/dev/null || {
  printf 'Session is unavailable: %s\n' "$SESSION" >&2
  exit 1
}

tmux capture-pane -p -t "$SESSION" -S -100
tmux send-keys -t "$SESSION" "$MESSAGE" Enter
sleep 3
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -150
```

- 使用 `send-keys ... Enter` 提交单行消息，不要模拟粘贴多行文本。
- 将消息作为单个参数传递，避免 shell 拆分；消息含敏感信息时避免在日志和最终回复中复述。
- 发送成功不等于模型已回复。等待后重新捕获，必要时每隔 5–10 秒轮询。
- 使用 `-S -100` 或更大的负数读取滚动历史；不要只根据屏幕底部判断回复状态。
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

## 4. 处理会话消失

典型错误：

```text
psmux: no server running on session 'gf-pi-hello'
```

或：

```text
can't find session: gf-pi-hello
```

这些错误说明**执行当前命令时**目标会话或服务端不可用，不能据此判断之前的消息是否送达，也不能据此断定回复失败。

按以下顺序处理：

1. 用 `tmux list-sessions` 确认当前状态；记录该命令自身的错误。
2. 若会话仍在，直接捕获输出，不要重建会话或重发消息。
3. 若会话消失，检查最后一份快照是否显示进程退出、错误或未提交的消息。
4. 状态未知时不要自动重发消息，避免模型收到重复请求。
5. 用户要求继续原对话时，优先恢复 gfcode 会话，而不是启动无关的新对话：

```bash
SESSION='gf-pi-hello'
tmux new-session -d -s "$SESSION" \
  'gf pi --continue world; status=$?; printf "\n[gf pi exited: %s]\n" "$status"; exec bash'
sleep 5
tmux has-session -t "$SESSION" 2>/dev/null && \
  tmux capture-pane -p -t "$SESSION" -S -150
```

`--continue` 恢复 gfcode 的对话记录，不会恢复已经退出的 tmux 服务端。只有在明确需要把消息作为恢复后的下一条用户消息时，才使用 `gf pi --continue <message>`；仅想查看旧会话时不要附加消息。

若 tmux 服务本身反复被宿主环境清理，保留 gfcode 会话用于恢复，并向用户说明无法保证 tmux 会话持续存活。不要承诺会话仍在，除非刚刚通过 `has-session` 验证。

## 5. 汇报与清理

汇报时包含：

- 实际使用的 tmux 会话名；
- 已提交的用户消息；
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
