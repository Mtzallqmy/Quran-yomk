FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends icecast2=2.4.4-4build4 ca-certificates nodejs wget && rm -rf /var/lib/apt/lists/*
COPY icecast.xml.template /opt/tarteel/icecast.xml.template
COPY render-config.mjs /opt/tarteel/render-config.mjs
COPY entrypoint.sh /opt/tarteel/entrypoint.sh
RUN chmod 0555 /opt/tarteel/entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/opt/tarteel/entrypoint.sh"]
