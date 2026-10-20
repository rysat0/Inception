FROM debian:bookworm

RUN apt-get update \
	&& apt-get install -y --no-install-recommends mariadb-server \
	&& rm -rf /var/lib/apt/lists/*

# Debianのパッケージ一覧取得->-yで確認入力スキップ->必須でないパッケージスキップ->MariaDB本体インストール->不要なパッケージ一覧を削除

COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf

# host side conf/mariadb.cnf --copy to--> /etc/mysql/mariadb.conf.d/99-inception.cnf

COPY tools/entrypoint.sh /usr/local/bin/mariadb-entrypoint.sh

RUN chmod 755 /usr/local/bin/mariadb-entrypoint.sh
