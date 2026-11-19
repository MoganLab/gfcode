# (code tests e2e) 端到端测试导览

跨进程、跨模块的 pi CLI 端到端测试目录，验证 CLI 参数解析、会话持久化、
工具调用链路与 JSON/交互模式的整体行为。

## 文件说明

- `pi-cli-e2e-support.scm` - 端到端测试公共夹具（临时配置目录、子进程启动等）
- `pi-cli-e2e-test.scm` - CLI 主体流程端到端测试
- `pi-json-e2e-test.scm` - JSON 模式输出端到端测试
- `pi-agent-test.scm` - agent 循环端到端测试
- `pi-app-queue-test.scm` - 交互模式输入队列端到端测试
- `pi-app-thinking-test.scm` - 思考级别展示端到端测试
- `pi-interactive-agent-test.scm` - 交互式 agent 集成测试
- `pi-execute-one-tool-call-test.scm` - 单次工具调用执行测试
- `pi-execute-tool-calls-test.scm` - 多次工具调用执行测试
- `pi-import-leak-test.scm` - 导入泄漏检查
- `run-agent-loop-injected-chan-e2e-test.scm` - 注入通道下的 agent 循环测试

## 运行方式

```bash
bin/gf test
```
