#!/usr/bin/env python3
"""OpenAI Responses API 兼容 stub：用于 openai-responses 协议端到端测试。

支持：
- POST /v1/responses 非流式：返回 output[] 文本
- POST /v1/responses 流式（stream=true）：返回 Responses SSE 事件序列
- 工具调用场景：请求 input 中出现 function_call_output 时返回最终文本
- Bearer 鉴权校验（test-key）
- 缓存命中模拟：request 携带 prompt_cache_key 时 usage.cached_tokens 非零
"""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def _usage(cached=0, reasoning=0):
    return {
        "input_tokens": 12 + cached,
        "output_tokens": 5,
        "input_tokens_details": {"cached_tokens": cached},
        "output_tokens_details": {"reasoning_tokens": reasoning},
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _read_json(self):
        length = int(self.headers.get("content-length", 0) or 0)
        raw = self.rfile.read(length) or b"{}"
        try:
            return json.loads(raw)
        except Exception:
            return {}

    def _reply(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _has_tool_output(self, req):
        items = req.get("input", [])
        if not isinstance(items, list):
            return False
        return any(isinstance(it, dict) and it.get("type") == "function_call_output" for it in items)

    def _last_user_text(self, req):
        items = req.get("input", [])
        for it in reversed(items if isinstance(items, list) else []):
            if isinstance(it, dict) and it.get("role") == "user":
                content = it.get("content")
                if isinstance(content, str):
                    return content
                if isinstance(content, list):
                    return "".join(p.get("text", "") for p in content if isinstance(p, dict))
        return ""

    def _stream(self, req):
        cached = 6 if req.get("prompt_cache_key") else 0
        has_tool_output = self._has_tool_output(req)
        # 工具调用往返：首轮发 function_call，次轮（带 output）发最终文本
        want_tool = (not has_tool_output) and ("tool" in self._last_user_text(req).lower())
        events = []
        events.append(("response.created", {"type": "response.created", "response": {"status": "in_progress"}}))
        if want_tool:
            events.append(("response.output_item.added", {
                "type": "response.output_item.added",
                "output_index": 0,
                "item": {"type": "function_call", "id": "fc_stub", "name": "bash", "call_id": "call_stub"},
            }))
            args = '{"command":"echo hi"}'
            for i in range(0, len(args), 8):
                events.append(("response.function_call_arguments.delta", {
                    "type": "response.function_call_arguments.delta",
                    "output_index": 0,
                    "item_id": "fc_stub",
                    "delta": args[i:i + 8],
                }))
            events.append(("response.output_item.done", {
                "type": "response.output_item.done",
                "output_index": 0,
                "item": {"type": "function_call", "id": "fc_stub", "call_id": "call_stub",
                         "name": "bash", "arguments": args},
            }))
        else:
            text = "tool-done" if has_tool_output else "PONG"
            events.append(("response.output_item.added", {
                "type": "response.output_item.added",
                "output_index": 0,
                "item": {"type": "message", "id": "msg_stub", "role": "assistant", "content": []},
            }))
            for ch in [text[i:i + 2] for i in range(0, len(text), 2)]:
                events.append(("response.output_text.delta", {
                    "type": "response.output_text.delta",
                    "output_index": 0,
                    "content_index": 0,
                    "item_id": "msg_stub",
                    "delta": ch,
                }))
            events.append(("response.output_item.done", {
                "type": "response.output_item.done",
                "output_index": 0,
                "item": {"type": "message", "id": "msg_stub", "role": "assistant",
                         "content": [{"type": "output_text", "text": text}]},
            }))
        events.append(("response.completed", {
            "type": "response.completed",
            "response": {"status": "completed", "usage": _usage(cached=cached)},
        }))

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        # 缓冲后一次性发送并带 Content-Length：客户端以响应体结束判定流完结，
        # 无 Content-Length 的 keep-alive 连接会让客户端等待到超时。
        body = "".join(
            "event: %s\ndata: %s\n\n" % (name, json.dumps(payload))
            for name, payload in events
        ).encode("utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _non_stream(self, req):
        cached = 6 if req.get("prompt_cache_key") else 0
        has_tool_output = self._has_tool_output(req)
        if has_tool_output:
            output = [{"type": "message", "id": "msg_stub", "role": "assistant",
                       "content": [{"type": "output_text", "text": "tool-done"}]}]
        elif "tool" in self._last_user_text(req).lower():
            output = [{"type": "function_call", "id": "fc_stub", "call_id": "call_stub",
                       "name": "bash", "arguments": '{"command":"echo hi"}'}]
        else:
            output = [{"type": "message", "id": "msg_stub", "role": "assistant",
                       "content": [{"type": "output_text", "text": "PONG"}]}]
        self._reply(200, {
            "id": "resp_stub",
            "object": "response",
            "status": "completed",
            "output": output,
            "usage": _usage(cached=cached),
        })

    def do_POST(self):  # noqa: N802
        if not self.path.rstrip("/").endswith("/responses"):
            self._reply(404, {"error": {"message": "not found"}})
            return
        auth = self.headers.get("authorization", "")
        if auth != "Bearer test-key":
            self._reply(401, {"error": {"message": "invalid api key", "type": "auth"}})
            return
        req = self._read_json()
        if req.get("stream"):
            self._stream(req)
        else:
            self._non_stream(req)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print("PORT:%d" % server.server_address[1], flush=True)
    server.serve_forever()
