FROM debian:bookworm

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		php8.2-fpm \
		php8.2-cli \
		php8.2-mysql \
		mariadb-client \
	&& rm -rf /var/lib/apt/lists/*

# php-fpm: execute php by receiving message from nginx

RUN curl -fsSL \
		https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
		-o /usr/local/bin/wp \
	&& chmod 755 /usr/local/bin/wp

# -f: deal HTTP error as fail
# -s: do not display progress bar or so
# -S: but error is going to still displayed
# -L: follow redirect
# -o: disignate path to be saved

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh

RUN chmod 755 /usr/local/bin/wordpress-entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
