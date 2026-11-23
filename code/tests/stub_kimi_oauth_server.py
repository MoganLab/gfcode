#!/usr/bin/env python3
"""Kimi Code OAuth2 stub server for gfcode unit tests (1402 §3.2).

Emulates https://auth.kimi.com endpoints:
  POST /api/oauth/device_authorization  -> device_code/user_code/verification URIs
  POST /api/oauth/token                 -> device_code grant polling & refresh_token grant

Scenario is chosen by the first CLI arg (default "ok"):
  ok            authorize OK; token poll: pending once, then complete
  slow-down     poll: pending, slow_down (with new interval), then complete
  denied        poll: access_denied
  expired       poll: expired_token
  poll-500      poll: HTTP 500
  authorize-500 device_authorization: HTTP 500
  authorize-bad device_authorization: 200 with missing fields
  refresh-ok    refresh grant returns fresh tokens immediately
  refresh-401   refresh grant returns 401 invalid_grant
  refresh-403   refresh grant returns 403
  refresh-flaky refresh grant: 429 twice then 200 (retry backoff path)
  refresh-500   refresh grant: always 500 (retries exhausted)

Prints "PORT:<port>" on stdout once listening.
"""
import http.server
import json
import sys
import urllib.parse

SCENARIO = sys.argv[1] if len(sys.argv) > 1 else "ok"


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, status: int, obj: dict) -> None:
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("content-length") or 0)
        except ValueError:
            self._send(400, {"error": "invalid_request"})
            return
        raw = self.rfile.read(length).decode("utf-8") if length else ""
        form = dict(urllib.parse.parse_qsl(raw))
        server = self.server
        server.token_polls = getattr(server, "token_polls", 0)
        server.refresh_calls = getattr(server, "refresh_calls", 0)

        if self.path == "/api/oauth/device_authorization":
            if form.get("client_id") != "17e5f671-d194-4dfb-9706-5516cb48c098":
                self._send(400, {"error": "invalid_client"})
                return
            if SCENARIO == "authorize-500":
                self._send(500, {"error": "server_error"})
                return
            if SCENARIO == "authorize-bad":
                self._send(200, {"user_code": "ABCD-1234"})
                return
            self._send(200, {
                "device_code": "stub-device-code",
                "user_code": "ABCD-1234",
                "verification_uri": "https://www.kimi.com/code",
                "verification_uri_complete":
                    "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234",
                "interval": 1,
                "expires_in": 900,
            })
            return

        if self.path == "/api/oauth/token":
            grant = form.get("grant_type")
            if grant == "urn:ietf:params:oauth:grant-type:device_code":
                if form.get("device_code") != "stub-device-code":
                    self._send(400, {"error": "invalid_grant"})
                    return
                server.token_polls += 1
                n = server.token_polls
                if SCENARIO == "denied":
                    self._send(400, {"error": "access_denied"})
                    return
                if SCENARIO == "expired":
                    self._send(400, {"error": "expired_token"})
                    return
                if SCENARIO == "poll-500":
                    self._send(500, {"error": "server_error"})
                    return
                if SCENARIO == "slow-down":
                    if n == 1:
                        self._send(400, {"error": "authorization_pending"})
                        return
                    if n == 2:
                        self._send(400, {"error": "slow_down", "interval": 1})
                        return
                else:
                    if n == 1:
                        self._send(400, {"error": "authorization_pending"})
                        return
                self._send(200, {
                    "access_token": "stub-access-token",
                    "refresh_token": "stub-refresh-token",
                    "expires_in": 3600,
                    "token_type": "Bearer",
                })
                return
            if grant == "refresh_token":
                server.refresh_calls += 1
                n = server.refresh_calls
                if form.get("refresh_token") == "dead-refresh-token" or SCENARIO == "refresh-401":
                    self._send(401, {"error": "invalid_grant",
                                     "error_description": "refresh token expired"})
                    return
                if SCENARIO == "refresh-403":
                    self._send(403, {"error": "access_denied"})
                    return
                if SCENARIO == "refresh-500":
                    self._send(500, {"error": "server_error"})
                    return
                if SCENARIO == "refresh-flaky" and n <= 2:
                    self._send(429, {"error": "rate_limited"})
                    return
                self._send(200, {
                    "access_token": "stub-access-token-2",
                    "refresh_token": "stub-refresh-token-2",
                    "expires_in": 3600,
                    "token_type": "Bearer",
                })
                return
            self._send(400, {"error": "unsupported_grant_type"})
            return

        self._send(404, {"error": "not_found"})


def main() -> None:
    # 仅绑定回环地址；测试结束时由 process-kill 终止，无需优雅关停
    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    print("PORT:%d" % server.server_address[1], flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()