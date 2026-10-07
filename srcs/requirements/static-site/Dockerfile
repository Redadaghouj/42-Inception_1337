FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends nginx && rm -rf /var/lib/apt/lists/* && rm -f /etc/nginx/sites-enabled/default

COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY site/ /var/www/html/

CMD ["nginx", "-g", "daemon off;"]
