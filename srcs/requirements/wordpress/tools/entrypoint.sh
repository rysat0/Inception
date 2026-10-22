#!/bin/sh
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD_FILE:?DB_PASSWORD_FILE is required}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${WP_TITLE:?WP_TITLE is required}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
: "${WP_USER:?WP_USER is required}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL is required}"
: "${WP_ADMIN_PASSWORD_FILE:?WP_ADMIN_PASSWORD_FILE is required}"
: "${WP_USER_PASSWORD_FILE:?WP_USER_PASSWORD_FILE is required}"

for secret_file in "$DB_PASSWORD_FILE" "$WP_ADMIN_PASSWORD_FILE" "$WP_USER_PASSWORD_FILE"; do
    if [ ! -r "$secret_file" ]; then
        echo "Error: cannot read secret file: $secret_file" >&2
        exit 1
    fi
done

DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
WP_ADMIN_PASSWORD="$(cat "$WP_ADMIN_PASSWORD_FILE")"
WP_USER_PASSWORD="$(cat "$WP_USER_PASSWORD_FILE")"

: "${DB_PASSWORD:?db_password secret is empty}"
: "${WP_ADMIN_PASSWORD:?wp_admin_password secret is empty}"
: "${WP_USER_PASSWORD:?wp_user_password secret is empty}"

if [ "$WP_ADMIN_USER" = "$WP_USER" ]; then
    echo "Error: WP_ADMIN_USER and WP_USER must be different" >&2
    exit 1
fi

mkdir -p /run/php /var/www/html
cd /var/www/html

wp_cmd() {
    wp --allow-root --path=/var/www/html "$@"
}

# "$@": 渡された引数をそのまま引き継ぐ

if [ ! -f wp-load.php ]; then
    wp_cmd core download
fi

if [ ! -f wp-config.php ]; then
    wp_cmd config create \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --dbcharset=utf8mb4 \
        --skip-check
fi


# attempt: recurring until it success. inside until, written process when it still failure
# >/dev/null: 標準出力を破棄する
# 2>&1: 標準エラー出力も標準出力に出力する
# $((...)): 算術処理
# -ge: 以上
attempt=0
until wp_cmd db query 'SELECT 1;' --connect-timeout=2 >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
        echo "Error: cannot connect to the WordPress database" >&2
        exit 1
    fi
    echo "Waiting for MariaDB..."
    sleep 2
done

if ! wp_cmd core is-installed; then
    wp_cmd core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
fi

if ! wp_cmd user get "$WP_USER" --field=ID >/dev/null 2>&1; then
    wp_cmd user create "$WP_USER" "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 -F
