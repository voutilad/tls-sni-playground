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
                conn.sendall("Hi, {addr}! I'm {HOST}.\n".encode("utf8"))
                while True:
                    data = conn.recv(512)
                    if not data: break
                    i = i + 1
                    try:
                        s = data.decode("utf8")
                        if not s.isprintable():
                            s = "[nonsense]"
                    except:
                        conn.close()
                    conn.sendall("You said ({i}): {s}".encode("utf8"))
                print(f"[{addr}] disconnected")

            while True:
                try:
                    conn, addr = ssock.accept()
                    print(f"[{addr}] connected")
                    pool.submit(echo, conn, addr)
                except ssl.SSLError as e:
                    pass
                except Exception as e:
                    print(e)
