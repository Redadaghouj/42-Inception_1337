FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends nginx openssl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/nginx/sites-enabled/default

RUN sed -i \
    's/ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;/ssl_protocols TLSv1.2 TLSv1.3;/' \
    /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/ssl && openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout /etc/nginx/ssl/inception.key -out /etc/nginx/ssl/inception.crt -subj "/CN=mdaghouj.42.fr"

COPY conf/default.conf /etc/nginx/conf.d/default.conf

CMD ["nginx", "-g", "daemon off;"]
