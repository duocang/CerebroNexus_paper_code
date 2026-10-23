"""Serve a Vitessce page, its locally bundled JS (vitessce@3.9.9) and the Zarr store from ONE localhost origin.
The vitessce.io hosted page cannot read localhost data from headless Chrome, so the page is served here.
Usage: serve_vitessce.py <artifact dir (data.zarr + config.json)> <port>"""
import http.server, json, mimetypes, os, socketserver, sys

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JS_DIR = os.path.join(HERE, "data", "inputs", "vitessce-js")
art, port = os.path.abspath(sys.argv[1]), int(sys.argv[2])
origin = f"http://127.0.0.1:{port}"
config = open(os.path.join(art, "config.json"), encoding="utf-8").read().replace("__ORIGIN__", origin)
INDEX = """<!doctype html><html><head><meta charset="utf-8"><title>vitessce</title>
<style>html,body{margin:0;height:100%}#root{width:100vw;height:100vh}</style></head>
<body><div id="root"></div>
<script type="module">
import './js/entry.js';
window.mountVitessce(__CONFIG__, document.getElementById('root'), window.innerHeight);
</script></body></html>""".replace("__CONFIG__", config)
mimetypes.add_type("text/javascript", ".js"); mimetypes.add_type("application/wasm", ".wasm"); mimetypes.add_type("text/css", ".css")

class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        if path.startswith("/js/"): return os.path.join(JS_DIR, path[4:])
        if path.startswith("/data.zarr"): return os.path.join(art, path[1:])
        return super().translate_path(path)
    def do_GET(self):
        if self.path.split("?", 1)[0] in ("/", "/index.html"):
            b = INDEX.encode("utf-8"); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b); return
        return super().do_GET()
    def guess_type(self, path):
        return mimetypes.guess_type(path)[0] or "application/octet-stream"
    def log_message(self, *a): pass

class S(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True; allow_reuse_address = True

S(("127.0.0.1", port), H).serve_forever()
