FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        openssl \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

# openssl: 学習環境用の自己署名証明書と秘密鍵作成
# gettext-base: 環境変数を設定ファイルへ埋め込むenvsubstを利用可能にする

RUN mkdir -p /etc/nginx/templates /etc/nginx/ssl

# /etc/nginx/ssl: TLS証明書と秘密鍵

COPY conf/nginx.conf /etc/nginx/templates/nginx.conf.template
COPY tools/entrypoint.sh /usr/local/bin/nginx-entrypoint.sh

RUN chmod 755 /usr/local/bin/nginx-entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/nginx-entrypoint.sh"]
