#!/usr/bin/env python3
"""HTTP/3 fixture for tests/smoke.sh (aioquic: an independent QUIC + TLS 1.3 + HTTP/3 implementation).

  smoke_h3_server.py PORT ROOT CERT KEY

Serves files under ROOT over HTTP/3 (any 404 is a 404 with a short body). /old answers 301 -> /index.html.
Binds the IPv6 wildcard (dual-stack) so both ::1 and 127.0.0.1 reach it. Prints READY when listening.
"""
import asyncio, mimetypes, os, sys
from aioquic.asyncio import serve, QuicConnectionProtocol
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived
from aioquic.quic.configuration import QuicConfiguration

ROOT = "."

class Srv(QuicConnectionProtocol):
    h3 = None

    def quic_event_received(self, event):
        if self.h3 is None:
            self.h3 = H3Connection(self._quic)
        for e in self.h3.handle_event(event):
            if isinstance(e, HeadersReceived):
                h = dict(e.headers)
                path = h.get(b":path", b"/").decode().split("?")[0]
                if path == "/old":
                    self.h3.send_headers(e.stream_id, [(b":status", b"301"), (b"location", b"/index.html")])
                    self.h3.send_data(e.stream_id, b"", end_stream=True)
                else:
                    fp = os.path.normpath(os.path.join(ROOT, path.lstrip("/") or "index.html"))
                    if fp.startswith(ROOT) and os.path.isfile(fp):
                        body = open(fp, "rb").read()
                        ct = (mimetypes.guess_type(fp)[0] or "application/octet-stream").encode()
                        self.h3.send_headers(e.stream_id, [(b":status", b"200"), (b"content-type", ct),
                                                           (b"x-served-by", b"aioquic-h3")])
                    else:
                        body = b"not found"
                        self.h3.send_headers(e.stream_id, [(b":status", b"404")])
                    self.h3.send_data(e.stream_id, body, end_stream=True)
                self.transmit()

async def main(port, root, cert, key):
    global ROOT
    ROOT = os.path.abspath(root)
    cfg = QuicConfiguration(is_client=False, alpn_protocols=H3_ALPN)
    cfg.load_cert_chain(cert, key)
    try:
        await serve("::", port, configuration=cfg, create_protocol=Srv)
    except OSError:
        await serve("127.0.0.1", port, configuration=cfg, create_protocol=Srv)
    print("READY", flush=True)
    await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]), sys.argv[2], os.path.abspath(sys.argv[3]), os.path.abspath(sys.argv[4])))
