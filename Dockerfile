FROM python:3.14.5-slim

RUN apt-get update && apt-get install -y git && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/idlesauce/umtx2.git .

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 53/udp 80 443

CMD ["/start.sh"]
