import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer


vllm_port = int(os.getenv("PORT", "8000"))
health_port = int(os.getenv("PORT_HEALTH", "8001"))


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/ping":
            self.send_response(404)
            self.end_headers()
            return

        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{vllm_port}/health",
                timeout=2,
            ) as response:
                status = 200 if response.status == 200 else 204
        except (urllib.error.URLError, TimeoutError):
            status = 204

        self.send_response(status)
        self.end_headers()
        if status == 200:
            self.wfile.write(b'{"status":"healthy"}')

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", health_port), HealthHandler)
    server.serve_forever()
