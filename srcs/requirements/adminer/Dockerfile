FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends php-cli php-mysql curl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/adminer && curl -fsSL https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php -o /var/www/adminer/index.php

WORKDIR /var/www/adminer

CMD ["php", "-S", "0.0.0.0:8080"]
