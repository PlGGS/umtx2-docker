FROM python:3.14.5-slim

RUN apt-get update && apt-get install -y git && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/plggs/umtx2.git .

COPY scripts/start.sh /app/scripts/start.sh
COPY scripts/update-etahen.sh /app/scripts/update-etahen.sh
COPY scripts/update-kstuff.sh /app/scripts/update-kstuff.sh
COPY scripts/update-websrv.sh /app/scripts/update-websrv.sh
COPY scripts/update-ftpsrv.sh /app/scripts/update-ftpsrv.sh
COPY scripts/update-klogsrv.sh /app/scripts/update-klogsrv.sh
COPY scripts/update-shsrv.sh /app/scripts/update-shsrv.sh
COPY scripts/update-gdbsrv.sh /app/scripts/update-gdbsrv.sh
COPY scripts/update-ps5debug.sh /app/scripts/update-ps5debug.sh
COPY scripts/update-ps5-linux-loader.sh /app/scripts/update-ps5-linux-loader.sh
COPY scripts/update-browser-appcache-remove.sh /app/scripts/update-browser-appcache-remove.sh

RUN chmod +x /app/scripts/start.sh \
        /app/scripts/update-etahen.sh \
        /app/scripts/update-kstuff.sh \
        /app/scripts/update-websrv.sh \
        /app/scripts/update-ftpsrv.sh \
        /app/scripts/update-klogsrv.sh \
        /app/scripts/update-shsrv.sh \
        /app/scripts/update-gdbsrv.sh \
        /app/scripts/update-ps5debug.sh \
        /app/scripts/update-ps5-linux-loader.sh \
        /app/scripts/update-browser-appcache-remove.sh

EXPOSE 53/udp 80 443

CMD ["/app/scripts/start.sh"]
