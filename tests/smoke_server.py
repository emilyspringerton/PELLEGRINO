#!/usr/bin/env python3
"""Tiny HTTP/1.0 (and HTTPS) fixture server for tests/smoke.sh.

  smoke_server.py PORT ROOT [CERT KEY] [--redirect-to URL]

Serves files under ROOT. /old answers 301 -> /index.html (relative) and, with --redirect-to, /hop answers
301 -> that absolute URL. With CERT and KEY it speaks TLS. Prints nothing; killed by the test.
"""
import http.server
import os
import socketserver
import ssl
import sys


def main():
    args = sys.argv[1:]
    redirect_to = None
    if "--redirect-to" in args:
        i = args.index("--redirect-to")
        redirect_to = args[i + 1]
        del args[i:i + 2]
    port, root = int(args[0]), args[1]
    cert, key = (os.path.abspath(args[2]), os.path.abspath(args[3])) if len(args) >= 4 else (None, None)
    os.chdir(root)

    class H(http.server.SimpleHTTPRequestHandler):
        protocol_version = "HTTP/1.0"

        def do_GET(self):
            if self.path == "/old":
                self.send_response(301)
                self.send_header("Location", "/index.html")
                self.end_headers()
                return
            if self.path == "/hop" and redirect_to:
                self.send_response(301)
                self.send_header("Location", redirect_to)
                self.end_headers()
                return
            return super().do_GET()

        def log_message(self, *a):
            pass

    class S(socketserver.ThreadingMixIn, http.server.HTTPServer):
        allow_reuse_address = True
        daemon_threads = True

    srv = S(("127.0.0.1", port), H)
    if cert:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cert, key)
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    srv.serve_forever()


main()
