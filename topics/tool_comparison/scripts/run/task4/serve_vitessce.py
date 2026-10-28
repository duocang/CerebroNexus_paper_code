"""Serve a Vitessce artifact (data.zarr + config.json), the page and the local vitessce@3.9.9 bundle
from one localhost origin, as scripts/run/serve_vitessce.py of Tasks 1-3.
Usage: serve_vitessce.py <artifact dir> <port> <bundle dir with entry.js>"""
import http.server, mimetypes, os, socketserver, sys

art, port, js_dir = os.path.abspath(sys.argv[1]), int(sys.argv[2]), os.path.abspath(sys.argv[3])
origin = f"http://127.0.0.1:{port}"
config = open(os.path.join(art, "config.json"), encoding="utf-8").read().replace("__ORIGIN__", origin)
INDEX = """<!doctype html><html><head><meta charset="utf-8"><title>vitessce</title>
<style>html,body{margin:0;height:100%}#root{width:100vw;height:100vh}</style></head>
<body><div id="root"></div>
<script type="module">
import './js/entry.js';
window.mountVitessce(__CONFIG__, document.getElementById('root'), window.innerHeight);
</script></body></html>""".replace("__CONFIG__", config)
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/css", ".css")


class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        if path.startswith("/js/"):
            return os.path.join(js_dir, path[4:])
        if path.startswith("/data.zarr"):
            return os.path.join(art, path[1:])
        return os.path.join(art, "__not_served__")

    def do_GET(self):
        if self.path.split("?", 1)[0] in ("/", "/index.html"):
            b = INDEX.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
            return
        return super().do_GET()

    def log_message(self, *a):
        pass


socketserver.TCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("127.0.0.1", port), H) as httpd:
    httpd.serve_forever()
