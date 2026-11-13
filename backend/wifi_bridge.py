"""Relay local development APIs to one phone on the Wi-Fi interface."""
import argparse
import ipaddress
import select
import socket
from socketserver import BaseRequestHandler, ThreadingTCPServer
from threading import Thread


class Bridge(ThreadingTCPServer):
    daemon_threads = True

    def __init__(self, address, phone):
        self.phone = phone
        super().__init__(address, Relay)

    def verify_request(self, request, client_address):
        return client_address[0] == self.phone


class Relay(BaseRequestHandler):
    def handle(self):
        try:
            with socket.create_connection(('127.0.0.1', self.server.server_address[1]), timeout=5) as upstream:
                upstream.settimeout(20)
                self.request.settimeout(20)
                peers = {self.request: upstream, upstream: self.request}
                readable = list(peers)
                while readable:
                    ready, _, _ = select.select(readable, [], [], 195)
                    if not ready:
                        return
                    for source in ready:
                        data = source.recv(65536)
                        if data:
                            peers[source].sendall(data)
                        else:
                            readable.remove(source)
                            peers[source].shutdown(socket.SHUT_WR)
        except OSError:
            return


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pc_address', type=ipaddress.IPv4Address)
    parser.add_argument('phone_address', type=ipaddress.IPv4Address)
    args = parser.parse_args()
    with Bridge((str(args.pc_address), 18080), str(args.phone_address)) as account, \
         Bridge((str(args.pc_address), 18081), str(args.phone_address)) as learning:
        Thread(target=account.serve_forever, daemon=True).start()
        print(f'Wi-Fi bridge listening on {args.pc_address}:18080 and :18081', flush=True)
        learning.serve_forever()
