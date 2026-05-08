# syntax=docker/dockerfile:1.7

ARG PHP_VERSION=8.4
ARG DEBIAN_VERSION=trixie
ARG WSC_REF=6.2.3

FROM debian:${DEBIAN_VERSION}-slim AS wsc_builder

ARG WSC_REF

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        sed \
        tar \
    ; \
    rm -rf /var/lib/apt/lists/*

COPY docker/build-wsc-installer.sh /usr/local/bin/build-wsc-installer

RUN set -eux; \
    chmod +x /usr/local/bin/build-wsc-installer; \
    build-wsc-installer "$WSC_REF" /usr/src/woltlab

FROM dunglas/frankenphp:1-php${PHP_VERSION}-${DEBIAN_VERSION}

ARG WSC_REF

LABEL org.opencontainers.image.title="WoltLab Suite on FrankenPHP"
LABEL org.opencontainers.image.description="Production-oriented FrankenPHP/Caddy runtime for WoltLab Suite Core"
LABEL org.opencontainers.image.source="https://github.com/SoftCreatRMedia/frankenphp-woltlab-suite"
LABEL org.opencontainers.image.licenses="ISC"

ENV WSC_REF="${WSC_REF}" \
    SERVER_NAME=":80" \
    PHP_MEMORY_LIMIT="512M" \
    PHP_UPLOAD_MAX_FILESIZE="64M" \
    PHP_POST_MAX_SIZE="64M" \
    PHP_MAX_EXECUTION_TIME="120" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="256" \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER="32" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="20000" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_REVALIDATE_FREQ="0" \
    FRANKENPHP_NUM_THREADS="1" \
    FRANKENPHP_MAX_THREADS="1" \
    FRANKENPHP_CONFIG=""

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
    ; \
    install-php-extensions \
        exif \
        gd \
        gmp \
        imagick \
        intl \
        mysqli \
        opcache \
        pdo_mysql \
        zip \
    ; \
    rm -rf /var/lib/apt/lists/*

COPY docker/php.ini /usr/local/etc/php/conf.d/zz-woltlab-production.ini
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY docker/docker-entrypoint.sh /usr/local/bin/wsc-entrypoint
COPY --from=wsc_builder --chown=www-data:www-data /usr/src/woltlab /usr/src/woltlab

RUN set -eux; \
    chmod +x /usr/local/bin/wsc-entrypoint; \
    find /app/public -mindepth 1 -maxdepth 1 -exec rm -rf {} +; \
    mkdir -p /app/public; \
    chown -R www-data:www-data /app

WORKDIR /app/public

VOLUME ["/app/public", "/data", "/config"]

ENTRYPOINT ["wsc-entrypoint"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
