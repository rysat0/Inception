#!/bin/sh


set -eu

: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_ROOT_PASSWORD_FILE:?DB_ROOT_PASSWORD_FILE is required}"
: "${DB_PASSWORD_FILE:?DB_PASSWORD_FILE is required}"

for secret_file in "$DB_ROOT_PASSWORD_FILE" "$DB_PASSWORD_FILE"; do
	if [ ! -r "$secret_file" ]; then
		echo "Error: cannot read secret file: $secret_file" >&2
		exit 1
	fi
done

DB_ROOT_PASSWORD="$(cat "$DB_ROOT_PASSWORD_FILE")"
DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"

: "${DB_ROOT_PASSWORD:?db_root_password secret is empty}"
: "${DB_PASSWORD:?db_password secret is empty}"

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then # if internalDB doesn't exist, then initialize db and make user 
	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--auth-root-authentication-method=normal \
		--skip-test-db

	mariadbd \
	--user=mysql \
	--datadir=/var/lib/mysql \
	--bootstrap \
	--skip-networking <<SQL
	CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
	CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
	ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
	FLUSH PRIVILEGES;
SQL
fi

exec mariadbd \
	--user=mysql \
	--datadir=/var/lib/mysql \
	--console
