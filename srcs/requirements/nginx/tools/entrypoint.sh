#!/bin/sh

set -eu


: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

CERT_FILE=/etc/nginx/ssl/inception.crt
KEY_FILE=/etc/nginx/ssl/inception.key

mkdir -p /etc/nginx/ssl

if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
	openssl req \
		-x509 \
		-nodes \
		-newkey rsa:2048 \
		-days 365 \
		-keyout "$KEY_FILE" \
		-out "$CERT_FILE" \
		-subj "/CN=$DOMAIN_NAME" \
		-addext "subjectAltName=DNS:$DOMAIN_NAME"

	chmod 600 "$KEY_FILE"
	chmod 644 "$CERT_FILE"
fi

# x509: 自己署名証明書作成

TEMPLATE_FILE=/etc/nginx/templates/nginx.conf.template
CONFIG_FILE=/etc/nginx/nginx.conf

envsubst '${DOMAIN_NAME}' \
	< "$TEMPLATE_FILE" \
	> "$CONFIG_FILE"

# $TEMPLATE_FILE -> < で標準入力へ渡す -> envsubst -> ${DOMAIN_NAME}を置換 -> 標準出力 -> > でファイルへ保存 -> $CONFIG_FILE

nginx -t

exec nginx -g 'daemon off;'
