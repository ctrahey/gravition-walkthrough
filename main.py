import platform, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer


arch = platform.machine()
greeting = f"Hello, World! I'm {arch}\n"
num_bytes = sys.getsizeof(greeting)


class MyServer(BaseHTTPRequestHandler):
  def do_GET(self):
    self.send_response(200, "OK")
    self.send_header('ContentLength', num_bytes)
    self.end_headers()
    self.flush_headers()
    self.wfile.write(str.encode(greeting))


if __name__ == "__main__":
  httpd = HTTPServer(('0.0.0.0', 8000), MyServer)
  httpd.serve_forever()
