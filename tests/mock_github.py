#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
"""A minimal GitHub issue-comments API for testing upsert-comment.sh. Prints its port, then serves."""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

COMMENTS = [
    {"id": 1, "user": {"login": "someone"}, "body": "<!-- marl-review -->\nplanted by a contributor"},
    {"id": 2, "user": {"login": "someone"}, "body": "Looks good"},
]
LOG = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/log":
            return self._send(200, {"log": LOG, "comments": COMMENTS})
        if re.match(r"^/repos/o/r/issues/7/comments\?per_page=100&page=1$", self.path):
            return self._send(200, COMMENTS)
        return self._send(404, {})

    def _body(self):
        return json.loads(self.rfile.read(int(self.headers["Content-Length"])))

    def do_POST(self):
        if self.path == "/repos/o/r/issues/7/comments" and self.headers.get("Authorization") == "Bearer t0k":
            data = self._body()
            COMMENTS.append({"id": 10 + len(COMMENTS), "user": {"login": "github-actions[bot]"}, "body": data["body"]})
            LOG.append("POST")
            return self._send(201, COMMENTS[-1])
        return self._send(403, {})

    def do_PATCH(self):
        match = re.match(r"^/repos/o/r/issues/comments/(\d+)$", self.path)
        if match:
            data = self._body()
            for comment in COMMENTS:
                if comment["id"] == int(match.group(1)):
                    comment["body"] = data["body"]
                    LOG.append(f"PATCH {comment['id']}")
                    return self._send(200, comment)
        return self._send(404, {})


server = HTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
