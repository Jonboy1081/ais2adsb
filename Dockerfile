FROM python:3.13-slim

LABEL org.opencontainers.image.source="https://github.com/jvde-github/ais2adsb"

RUN pip install --no-cache-dir aiscat

COPY ais2adsb.py /usr/local/bin/ais2adsb.py
COPY data/ /usr/local/bin/data/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 9000/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
