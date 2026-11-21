# (liii pi ai api openai-responses) 模块函数索引

`(liii pi ai api openai-responses)` 是 OpenAI Responses 协议（`POST /v1/responses`）
的统一入口，汇总并重新导出各子库的公开函数：

- `(liii pi ai api openai-responses core)` — 响应状态/usage 映射、响应解析与重试判定
- `(liii pi ai api openai-responses msg)` — 请求体组装（input 扁平 item、扁平工具声明、
  系统提示置于 input[0] 以纳入可缓存前缀）、prompt cache key 解析
- `(liii pi ai api openai-responses thinking)` — 请求侧 reasoning.effort 参数
- `(liii pi ai api openai-responses request)` — 端点构造、请求头与非流式请求
- `(liii pi ai api openai-responses stream)` — 流式请求
- `(liii pi ai api openai-responses stream-parse)` — Responses SSE 事件解析与增量累积
- `(liii pi ai api openai-responses stream-state)` — 流状态读写

使用时导入：

```scheme
(import (liii pi ai api openai-responses))
```

## 查看函数文档

使用以下命令查看函数文档和测试用例：

```bash
gf doc responses-request
```

或者指定库名：

```bash
gf doc liii/pi/ai/api/openai-responses "responses-request"
```

## 函数分类索引

### 响应字段映射
- `responses-map-stop-reason` - 将 Responses 响应 status 映射到 pi agent 标准 stopReason
- `responses-map-usage` - 将 Responses usage 对象映射为标准 usage alist（含 cached_tokens）

### 请求构造与端点
- `responses-build-tool-declarations` - 将内部 tool-definition records 转换为 Responses 扁平工具声明
- `responses-build-tool-declarations-from-names` - 根据内置工具名列表构建工具声明
- `responses-build-messages` - 将内部消息历史转换为 Responses input item 数组；系统提示置于 input[0]
- `responses-build-request-body` - 组装 Responses 请求体（model/input/store/tools/stream/reasoning）
- `responses-resolve-prompt-cache-key` - 解析 prompt_cache_key（仅官方端点注入）
- `responses-clamp-prompt-cache-key` - 截断 prompt_cache_key 到 64 字符
- `responses-build-endpoint` - 构造发往 Responses 端点的完整 URL
- `responses-build-headers` - 构造 HTTP 请求头（Bearer + 自定义 headers）
- `responses-build-proxy-alist` - 根据代理 URL 构造 HTTP/HTTPS 代理配置表

### 响应解析与重试判定
- `responses-parse-response` - 将 Responses JSON 响应解析为内部 assistant message
- `responses-is-retriable-error?` - 判断 Responses 请求失败是否可重试

### 请求发起
- `responses-request` - Responses 协议的非流式请求
- `responses-request-stream` - Responses 协议的流式请求

### 流式解析
- `append-responses-stream-text` - 向流状态追加正文增量，并派发 text_start / text_delta 事件
- `process-responses-tool-call-delta` - 处理 function_call_arguments 增量，累积参数
- `finish-responses-stream` - 完成流，将累积的工具调用转换为 toolCall 块
- `process-responses-chunk` - 处理单个 Responses SSE 事件载荷
- `make-responses-stream-decoder` - 创建 Responses SSE 解码器（终态事件后停止）
- `extract-responses-stream-error-message` - 从 Responses 错误响应体中提取错误信息

## 缓存优化要点

OpenAI 对 GPT-5/6 模型仅按序列化后的 `input` 数组 + `tools` 计算 prompt cache 前缀，
顶层 `instructions` 不计入缓存（GPT-6.2+ 还会排在 input 之后，命中边界外）。因此本实现：

- 系统提示一律以 `role="system"` 消息置于 `input[0]`，与会话历史、工具一起构成稳定前缀；
- 每轮只在尾部追加新 user 消息，前缀保持不变，最大化缓存命中；
- `store=false`：无状态请求，每次带全量 input，不依赖服务端会话；
- `prompt_cache_key` 仅对官方端点注入（第三方兼容端点保守不注入，避免未知字段报错），
  主要靠输入前缀稳定命中缓存，不依赖该字段。

## 运行测试

```bash
gf test ai/tests/liii/pi/ai/api/openai-responses/
```

## 测试文件索引

- `core/responses-parse-response-test.scm` — `responses-map-stop-reason`/`responses-map-usage`/`responses-parse-response`：状态与 usage 映射、响应解析
- `msg/responses-build-messages-test.scm` — `responses-build-messages`/`responses-build-request-body`/`responses-build-tool-declarations`：input item、工具声明与请求体
- `msg/responses-cache-optimization-test.scm` — 缓存优化：系统提示置于 input[0]、前缀稳定、prompt_cache_key 解析
- `stream-parse/process-responses-chunk-test.scm` — `process-responses-chunk`/`make-responses-stream-decoder`：SSE 事件解析
- `request/responses-request-test.scm` — `responses-request`/`responses-request-stream`：非流式/流式集成测试
