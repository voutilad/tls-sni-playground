#!/usr/bin/env python3
import os
import sys

import socket
import ssl

from concurrent.futures import ThreadPoolExecutor


TLS_CERT = os.environ.get("TLS_CERT", "ca.crt")
TLS_PKEY = os.environ.get("TLS_PKEY", "private.key")

context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
try:
    print(f"Loading x509 cert '{TLS_CERT}' and private key '{TLS_PKEY}'")
    context.load_cert_chain("ca.crt", "private.key")
except ssl.SSLError as e:
    print(f"SSLError: {e.strerror}")
    sys.exit(1)
except Exception as e:
    print(f"Unexpected exception: {e}")
    sys.exit(1)

HOST = os.environ.get("HOST", "127.0.0.1")
PORT = os.environ.get("PORT", 8888)

with socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0) as sock:
    # Start looking for friends out in the ether...
    addr = (HOST, PORT)
    print(f"Binding to {addr}")
    try:
        sock.bind(addr)
        sock.listen(5)
    except Exception as e:
        print(e)
        sys.exit(1)

    # Wrap with TLS...
    with context.wrap_socket(sock, server_side=True) as ssock:
        with ThreadPoolExecutor(max_workers=2) as pool:
            def echo(conn, addr):
                i = 0
                conn.settimeout(3)
                conn.sendall(f"Hi, {addr[0]}:{addr[1]}! I'm {HOST}.\n".encode("utf8"))
                while True:
                    try:
                        data = conn.recv(512)
                        if not data: break
                        i = i + 1
                        s = data.decode("utf8")
                        # TODO: printability?
                        conn.sendall(f"You said ({i}): {s}".encode("utf8"))
                    except:
                        conn.close()
                        break
                print(f"[{addr}] disconnected")

            while True:
                try:
                    conn, addr = ssock.accept()
                    print(f"[{addr}] connected")
                    pool.submit(echo, conn, addr)
                except ssl.SSLError as e:
                    pass
                except Exception as e:
                    break
