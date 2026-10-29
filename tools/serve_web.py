#!/usr/bin/env python3
"""Serve the exported game locally; no third-party dependencies."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parents[1] / "build/web")
    args = parser.parse_args()
    if not (args.directory / "index.html").is_file():
        parser.error("Build missing. Run ./tools/build_web.sh first.")
    server = ThreadingHTTPServer((args.host, args.port), partial(GameHandler, directory=str(args.directory.resolve())))
    print(f"Kosmosekuller: http://{args.host}:{args.port} (Ctrl+C stops the server)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
