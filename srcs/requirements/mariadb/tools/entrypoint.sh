#!/bin/sh

# -e: if any command fail(other than exit code 0), terminate script at that point
# -u: if undefined variables are used, then make it as error
set -eu

# environment variables existance check
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_ROOT_PASSWORD_FILE:?DB_ROOT_PASSWORD_FILE is required}"
: "${DB_PASSWORD_FILE:?DB_PASSWORD_FILE is required}"

# check two password files
# -r: check if designated path existed, and readable
for secret_file in "$DB_ROOT_PASSWORD_FILE" "$DB_PASSWORD_FILE"; do
	if [ ! -r "$secret_file" ]; then
		echo "Error: cannot read secret file: $secret_file" >&2 # >&2: output to stderr
		exit 1
	fi
done

DB_ROOT_PASSWORD="$(cat "$DB_ROOT_PASSWORD_FILE")"
DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"

: "${DB_ROOT_PASSWORD:?db_root_password secret is empty}"
: "${DB_PASSWORD:?db_password secret is empty}"

# -p: make dir even parent dir, if path doesn't exist, won't output error
# /run/mysqld: place that save files related during execution like socket or smth
# /var/lib/mysql: location taht DB datas save
# -R: apply recurrsive to child dirs
# mysql:mysql: 所有ユーザー change to mysql, 所有グループ change to mysql

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

INIT_MARKER=/var/lib/mysql/.inception-initialized

# /var/lib/mysql/mysql: MariaDBの管理用DB
if [ ! -d /var/lib/mysql/mysql ]; then
	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--auth-root-authentication-method=normal \
		--skip-test-db
fi

# 初期設定の途中で失敗した場合は、次回起動でSQLを再実行する
if [ ! -f "$INIT_MARKER" ]; then
	mariadbd \
	--user=mysql \
	--datadir=/var/lib/mysql \
	--bootstrap \
	--skip-networking <<SQL # heredoc
	FLUSH PRIVILEGES;
	CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
	CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
	ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
SQL
	# すべてのSQLが成功した場合だけ、初期設定の完了を記録する
	touch "$INIT_MARKER"
fi

# exec: replace nowgoing shell process to child process -> PID 1 at this situation
exec mariadbd \
	--user=mysql \
	--datadir=/var/lib/mysql \
	--console
