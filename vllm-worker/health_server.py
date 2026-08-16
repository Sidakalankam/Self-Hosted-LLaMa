import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer


VLLM_PORT = int(os.getenv("PORT", "8000"))
HEALTH_PORT = int(os.getenv("PORT_HEALTH", "8001"))


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/ping":
            self.send_response(404)
            self.end_headers()
            return

        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{VLLM_PORT}/health",
                timeout=2,
            ) as response:
                status = 200 if response.status == 200 else 204

        except (urllib.error.URLError, TimeoutError, OSError):
            # vLLM hasn't started yet, is loading the model,
            # or is temporarily unavailable.
            status = 204

        self.send_response(status)
        if status == 200:
            self.send_header("Content-Type", "application/json")
        self.end_headers()

        if status == 200:
            self.wfile.write(b'{"status":"healthy"}')

    def log_message(self, format, *args):
        # Disable default HTTP request logging.
        return


if __name__ == "__main__":
    print(f"Health server listening on port {HEALTH_PORT}", flush=True)

    server = HTTPServer(
        ("0.0.0.0", HEALTH_PORT),
        HealthHandler,
    )

    server.serve_forever()
