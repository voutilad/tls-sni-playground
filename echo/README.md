# echo

A simple Python-based TLS echo application

Uses the following environment variables for configuration:

- `HOST` -- ip or hostname to bind to
- `PORT` -- tcp port to bind
- `TLS_CERT` -- path to x509 certificate
- `TLS_PKEY` -- path to private key file

Will listen for incoming TLS-based connections. Initial message back
to the client will echo the `HOST` information, identifying which
instance the client reached. Any subsequent messages will be echoed
back to the client until connection drops or times out (default is
10s).
