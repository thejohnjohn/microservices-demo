#!/usr/bin/env python3
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

GRPCURL = os.path.expanduser("~/go/bin/grpcurl")
PROTO = os.path.expanduser("~/Tech/Dev/microservices-demo/protos/demo.proto")
IMPORT = os.path.expanduser("~/Tech/Dev/microservices-demo/protos")


def seed_cart(user_id):
    payload = json.dumps(
        {"user_id": user_id, "item": {"product_id": "OLJCESPC7Z", "quantity": 2}}
    )
    subprocess.run(
        [
            GRPCURL,
            "-plaintext",
            "-import-path",
            IMPORT,
            "-proto",
            PROTO,
            "-d",
            payload,
            "localhost:7070",
            "hipstershop.CartService/AddItem",
        ],
        check=True,
        capture_output=True,
    )
    print(f"seeded cart for user '{user_id}' via CartService/AddItem")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        state = body.get("state", "")
        print(f"state change: {state}")
        if "abc123" in state:
            seed_cart("abc123")
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8090), Handler)
    print("provider state server on :8090")
    server.serve_forever()