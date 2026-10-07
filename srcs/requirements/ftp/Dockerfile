FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends vsftpd passwd && rm -rf /var/lib/apt/lists/*

COPY conf/vsftpd.conf /etc/vsftpd.conf
COPY --chmod=0755 tools/init.sh /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["/usr/sbin/vsftpd", "/etc/vsftpd.conf"]
