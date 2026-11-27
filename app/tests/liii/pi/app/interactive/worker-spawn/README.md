# worker-spawn

`worker-spawn` 负责 TUI 后台 worker 的启动结果轮询。

`go` 的前导 import 发生在目标函数执行之前；函数体内的 `catch` 无法处理
此阶段的失败。这里使用 `go-apply/source` 的结果 channel，将启动失败交给
TUI 主线程并写入 `pi` 日志，长期运行的 worker 不会被轮询阻塞。
