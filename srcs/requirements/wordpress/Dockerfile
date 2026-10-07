FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends php-fpm php-mysql php-curl php-gd php-intl php-mbstring php-xml php-zip curl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf

RUN printf '\nenv[DB_NAME] = $DB_NAME\nenv[DB_USER] = $DB_USER\n' >> /etc/php/8.2/fpm/pool.d/www.conf

RUN mkdir -p /usr/src/wordpress && curl -fsSL https://wordpress.org/wordpress-7.1.2.tar.gz -o /tmp/wordpress.tar.gz && tar -xzf /tmp/wordpress.tar.gz --strip-components=1 -C /usr/src/wordpress && rm /tmp/wordpress.tar.gz

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp && chmod +x /usr/local/bin/wp

COPY --chmod=0755 tools/init.sh /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["php-fpm8.2", "-F"]

