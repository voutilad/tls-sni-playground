#!/usr/bin/env python3
import os
import sys
import signal

import socket
import ssl

from threading import Event
from concurrent.futures import ThreadPoolExecutor

# Global event for quiescing.
TIME_TO_DIE = Event()
def sighandler(signum, frame):
    TIME_TO_DIE.set()
signal.signal(signal.SIGINT|signal.SIGTERM, sighandler)
CLIENTS = set()

TLS_CERT = os.environ.get("TLS_CERT", "ca.crt")
TLS_PKEY = os.environ.get("TLS_PKEY", "private.key")

context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
try:
    print(f"Loading x509 cert '{TLS_CERT}' and private key '{TLS_PKEY}'")
    context.load_cert_chain(TLS_CERT, keyfile=TLS_PKEY)
except ssl.SSLError as e:
    print(f"SSLError: {e.strerror}")
    sys.exit(1)
except Exception as e:
    print(f"Unexpected exception: {e}")
    sys.exit(1)

HOST = os.environ.get("HOST", "127.0.0.1")
PORT = os.environ.get("PORT", 8888)

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    # Start looking for friends out in the ether...
    addr = (HOST.rstrip("."), PORT)
    print(f"Binding to {addr}.")
    try:
        sock.bind(addr)
        sock.listen(5)
        print(f"Listening on {addr}.")
    except Exception as e:
        print(e)
        sys.exit(1)

    # Wrap with TLS...
    with context.wrap_socket(sock, server_side=True) as ssock:
        ssock.settimeout(1)
        with ThreadPoolExecutor(max_workers=2) as pool:
            # Our client handler.
            def echo(conn, addr):
                i = 0
                conn.settimeout(10)
                conn.sendall(f"Hi, {addr[0]}:{addr[1]}! I'm {HOST}.\n".encode("utf8"))
                while True and not TIME_TO_DIE.is_set():
                    try:
                        data = conn.recv(512)
                        if not data: break
                        i = i + 1
                        s = data.decode("utf8")
                        # TODO: printability?
                        conn.sendall(f"You said ({i}): {s}".encode("utf8"))
                    except:
                        break
                CLIENTS.remove(conn)
                conn.shutdown(socket.SHUT_RDWR)
                conn.close()
                print(f"[{addr}] disconnected")

            # Main listener loop.
            while True and not TIME_TO_DIE.is_set():
                try:
                    conn, addr = ssock.accept()
                    CLIENTS.add(conn)
                    print(f"[{addr}] connected")
                    pool.submit(echo, conn, addr)
                except ssl.SSLError as e:
                    pass
                except Exception as e:
                    pass

            # Kill any connections.
            for client in CLIENTS:
                client.shutdown(socket.SHUT_RDWR)
                client.close()
