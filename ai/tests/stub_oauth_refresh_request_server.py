#!/usr/bin/env python3
"""OpenAI endpoint for the OAuth access-token propagation regression test."""

import http.server
import json


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, status: int, obj: dict) -> None:
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        length = int(self.headers.get("content-length") or 0)
        self.rfile.read(length)
        if self.headers.get("Authorization") != "Bearer new-access":
            self._send(401, {"error": {"message": "expired access token"}})
            return
        self._send(200, {
            "id": "chatcmpl-oauth-refresh",
            "object": "chat.completion",
            "created": 1,
            "model": "kimi-for-coding",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "PlainOK:new-access"},
                "finish_reason": "stop",
            }],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
        })

    def log_message(self, *args) -> None:
        pass


def main() -> None:
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print("PORT:%d" % server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
