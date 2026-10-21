# Keep the stable panel application/assets while replacing the vulnerable PHP
# runtime. Neither updating apk nor pulling the old panel tag updates PHP.
FROM ghcr.io/pterodactyl/panel@sha256:e27a06cfcd078691ddf9805ae0dee2ee529b35ce18e427ef970de4d503602f2c AS panel
FROM php:8.3.36-fpm-alpine@sha256:3ea3c3f8ee03269b77f5c2bda5879b44ba152cb13aafead8b67c4332f829aa2d

WORKDIR /app
RUN apk add --no-cache --update ca-certificates dcron curl git supervisor tar unzip nginx libpng-dev libxml2-dev libzip-dev certbot certbot-nginx mysql-client \
    && docker-php-ext-configure zip \
    && docker-php-ext-install bcmath gd pdo_mysql zip \
    && update-ca-certificates \
    && mkdir -p /var/run/php /var/run/nginx /var/log/supervisord \
    && sed -i s/ssl_session_cache/#ssl_session_cache/g /etc/nginx/nginx.conf

COPY --from=panel --chown=nginx:nginx /app /app
COPY --from=panel /usr/local/etc/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --from=panel /etc/supervisord.conf /etc/supervisord.conf
COPY --from=panel /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf
COPY --from=panel /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root

RUN php -r 'exit(version_compare(PHP_VERSION, "8.3.36", ">=") ? 0 : 1);' \
    && php-fpm -t

LABEL org.opencontainers.image.title="Pterodactyl 1.15.1 with PHP security fixes" \
      org.opencontainers.image.version="1.15.1-php8.3.36-20261021"
EXPOSE 80 443
ENTRYPOINT ["/bin/ash", ".github/docker/entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
