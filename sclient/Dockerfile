FROM alpine:3.18
RUN apk add --force-refresh openssl
COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
