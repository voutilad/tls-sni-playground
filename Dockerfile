FROM alpine:3.18
RUN mkdir /app && \
    adduser -D snek && \
    apk add --force-refresh python3
USER snek
WORKDIR /app
COPY ./app.py /app
ENTRYPOINT [ "python3" ]
CMD [ "app.py" ]
