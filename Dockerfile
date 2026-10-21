# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=wodby/drupal-php@sha256:a97a10f209006fdd5ead19b4ccb47ae6a53044ba48942c1597b505eb84d5c55a
FROM ${BASE_IMAGE}

USER root

ARG PHP_BASE_COMMIT=004cb827501d1ddaf98daacb185a53e0816f78a7
ARG PHP_SECURITY_COMMIT=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2
ARG PATCH_SHA256=de1b914a84b25196b82ede7d8c0031d43be72f232b259b984e7ef72507b10631

COPY patches/CVE-2026-109618-109619.patch /tmp/php-security.patch

RUN set -eux; \
    echo "${PATCH_SHA256}  /tmp/php-security.patch" | sha256sum -c -; \
    apk add --no-cache --virtual .php-backport-build-deps \
        ${PHPIZE_DEPS} \
        argon2-dev \
        bison \
        coreutils \
        curl-dev \
        git \
        gnu-libiconv-dev \
        libsodium-dev \
        libxml2-dev \
        linux-headers \
        oniguruma-dev \
        openssl-dev \
        readline-dev \
        sqlite-dev; \
    git clone --filter=blob:none --no-checkout https://github.com/php/php-src.git /usr/src/php-backport; \
    cd /usr/src/php-backport; \
    git fetch --depth=1 origin "${PHP_BASE_COMMIT}"; \
    git checkout --detach "${PHP_BASE_COMMIT}"; \
    test "$(git rev-parse HEAD)" = "${PHP_BASE_COMMIT}"; \
    sed 's/\r$//' /tmp/php-security.patch > /tmp/php-security-normalized.patch; \
    git apply --check /tmp/php-security-normalized.patch; \
    git apply /tmp/php-security-normalized.patch; \
    mkdir -p /tmp/gnu-libiconv/include /tmp/gnu-libiconv/lib; \
    ln -s /usr/include/gnu-libiconv/iconv.h /tmp/gnu-libiconv/include/iconv.h; \
    ln -s /usr/lib/libiconv.so /tmp/gnu-libiconv/lib/libiconv.so; \
    export \
        CFLAGS="${PHP_CFLAGS}" \
        CPPFLAGS="${PHP_CPPFLAGS}" \
        LDFLAGS="${PHP_LDFLAGS}"; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./buildconf --force; \
    ./configure \
        --build="${gnuArch}" \
        --with-config-file-path="${PHP_INI_DIR}" \
        --with-config-file-scan-dir="${PHP_INI_DIR}/conf.d" \
        --enable-option-checking=fatal \
        --with-mhash \
        --with-pic \
        --enable-ftp \
        --enable-mbstring \
        --enable-mysqlnd \
        --with-password-argon2 \
        --with-sodium=shared \
        --with-pdo-sqlite=/usr \
        --with-sqlite3=/usr \
        --with-curl \
        --with-iconv=/tmp/gnu-libiconv \
        --with-openssl \
        --with-readline \
        --with-zlib \
        --disable-phpdbg \
        --with-pear \
        --disable-cgi \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data; \
    make -j "$(getconf _NPROCESSORS_ONLN)"; \
    make install; \
    find /usr/local -type f -perm /0111 -exec sh -c 'strip --strip-all "$1" || :' _ '{}' \;; \
    php --version; \
    php-fpm --test; \
    rm -rf /usr/src/php-backport /tmp/gnu-libiconv /tmp/php-security.patch /tmp/php-security-normalized.patch; \
    apk del --no-network .php-backport-build-deps

LABEL org.opencontainers.image.source="https://github.com/php/php-src" \
      org.opencontainers.image.description="Minimal PHP 7.4 mitigation for CVE-2026-109618 and CVE-2026-109619" \
      org.opencontainers.image.base.name="docker.io/wodby/drupal-php:7.4" \
      org.opencontainers.image.revision="${PHP_SECURITY_COMMIT}"

USER wodby
