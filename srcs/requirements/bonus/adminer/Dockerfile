FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        php8.2-cli \
        php8.2-fpm \
        php8.2-mysql \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/php /var/www/adminer \
    && curl -fsSL \
        https://github.com/vrana/adminer/releases/download/v6.2.0/adminer-6.2.0-mysql.php \
        -o /var/www/adminer/index.php \
    && php -l /var/www/adminer/index.php

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

WORKDIR /var/www/adminer

EXPOSE 9000

CMD ["php-fpm8.2", "-F"]
