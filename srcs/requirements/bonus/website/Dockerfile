FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*

COPY conf/website.conf /etc/nginx/nginx.conf
COPY site/ /var/www/website/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
