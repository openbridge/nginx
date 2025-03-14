# Stage 1: Build NGINX with modules
FROM alpine:3.21 AS builder

# Build arguments for better versioning
ARG NGINX_VERSION=1.27.4
ARG NGX_BROTLI_COMMIT=master
ARG NGX_NDK_VERSION=0.3.3
ARG NGX_SET_MISC_VERSION=0.33
ARG NGX_REDIS_VERSION=0.4.1-cmm
ARG NGX_REDIS2_VERSION=0.15
ARG NGX_SRCACHE_VERSION=0.33
ARG NGX_CACHE_PURGE_VERSION=2.3

# Enhanced metadata
LABEL maintainer="Thomas Spicer (thomas@openbridge.com)"
LABEL org.opencontainers.image.version="${NGINX_VERSION}"
LABEL org.opencontainers.image.description="NGINX with enhanced modules"
LABEL org.opencontainers.image.licenses="MIT"

# Define environment variables
ENV VAR_PREFIX=/var/run \
    LOG_PREFIX=/var/log/nginx \
    TEMP_PREFIX=/tmp \
    CACHE_PREFIX=/var/cache \
    CONF_PREFIX=/etc/nginx \
    CERTS_PREFIX=/etc/pki/tls \
    NGINX_DOCROOT=/usr/share/nginx/html \
    GEOIP_PREFIX=/usr/share/geoip

# Set working directory to NGINX_DOCROOT
WORKDIR ${NGINX_DOCROOT}

# Create www-data user and group
RUN if ! getent group www-data >/dev/null; then \
    addgroup -g 82 -S www-data; \
    fi \
    && if ! getent passwd www-data >/dev/null; then \
    adduser -u 82 -D -S -h /var/cache/nginx -s /sbin/nologin -G www-data www-data; \
    fi

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    alpine-sdk \
    autoconf \
    automake \
    binutils \
    build-base \
    ca-certificates \
    cmake \
    findutils \
    g++ \
    gcc \
    gd-dev \
    geoip-dev \
    gettext \
    git \
    gnupg \
    go \
    gzip \
    libc-dev \
    libgcc \
    libstdc++ \
    libedit-dev \
    libmaxminddb-dev \
    libtool \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    make \
    mercurial \
    musl-dev \
    ninja \
    openssl-dev \
    pcre-dev \
    perl-dev \
    readline-dev \
    unzip \
    zlib-dev \
    zstd-dev

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    curl \
    libmaxminddb-libs \
    openssl \
    pcre \
    tar \
    tini \
    wget

# Handle envsubst installation
RUN apk add --no-cache gettext \
    && mv /usr/bin/envsubst /tmp/envsubst \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u \
    )" \
    && apk add --no-cache --virtual .envsubst-deps $runDeps \
    && mv /tmp/envsubst /usr/local/bin/

# Download and prepare all modules
RUN set -x \
    && mkdir -p /usr/src \
    && cd /tmp \
    && git clone --depth=1 --branch ${NGX_BROTLI_COMMIT} https://github.com/google/ngx_brotli \
    && cd ngx_brotli && git submodule update --init && cd .. \
    && git clone https://github.com/openresty/echo-nginx-module.git \
    && git clone https://github.com/tokers/zstd-nginx-module.git \
    && git clone https://github.com/nginx/njs.git \
    && git clone https://github.com/leev/ngx_http_geoip2_module.git \
    && git clone https://github.com/openresty/headers-more-nginx-module.git \
    && wget -O dev.zip https://github.com/vision5/ngx_devel_kit/archive/v${NGX_NDK_VERSION}.zip \
    && wget -O setmisc.zip https://github.com/openresty/set-misc-nginx-module/archive/v${NGX_SET_MISC_VERSION}.zip \
    && wget -O ngx.zip https://github.com/centminmod/ngx_http_redis/archive/${NGX_REDIS_VERSION}.zip \
    && wget -O redis.zip https://github.com/openresty/redis2-nginx-module/archive/v${NGX_REDIS2_VERSION}.zip \
    && wget -O cache.zip https://github.com/openresty/srcache-nginx-module/archive/v${NGX_SRCACHE_VERSION}.zip \
    && wget -O purge.zip https://github.com/FRiCKLE/ngx_cache_purge/archive/${NGX_CACHE_PURGE_VERSION}.zip \
    && unzip '*.zip' \
    && wget -O nginx.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -zxvf nginx.tar.gz -C /usr/src \
    && rm nginx.tar.gz

# NGINX configuration
ENV CONFIG="\
    --prefix=/usr/share/nginx/ \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=${CONF_PREFIX}/nginx.conf \
    --error-log-path=${LOG_PREFIX}/error.log \
    --http-log-path=${LOG_PREFIX}/access.log \
    --pid-path=${VAR_PREFIX}/nginx.pid \
    --lock-path=${VAR_PREFIX}/nginx.lock \
    --http-client-body-temp-path=${CACHE_PREFIX}/client_temp \
    --http-proxy-temp-path=${CACHE_PREFIX}/proxy_temp \
    --http-fastcgi-temp-path=${CACHE_PREFIX}/fastcgi_temp \
    --http-uwsgi-temp-path=${CACHE_PREFIX}/uwsgi_temp \
    --http-scgi-temp-path=${CACHE_PREFIX}/scgi_temp \
    --user=www-data \
    --group=www-data \
    --with-http_ssl_module \
    --with-openssl-opt=enable-ktls \
    --with-pcre-jit \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
    --with-http_v3_module \
    --add-module=/tmp/ngx_cache_purge-${NGX_CACHE_PURGE_VERSION} \
    --add-module=/tmp/ngx_http_redis-${NGX_REDIS_VERSION} \
    --add-dynamic-module=/tmp/ngx_http_geoip2_module \
    --add-module=/tmp/redis2-nginx-module-${NGX_REDIS2_VERSION} \
    --add-module=/tmp/srcache-nginx-module-${NGX_SRCACHE_VERSION} \
    --add-module=/tmp/echo-nginx-module \
    --add-module=/tmp/ngx_devel_kit-${NGX_NDK_VERSION} \
    --add-module=/tmp/set-misc-nginx-module-${NGX_SET_MISC_VERSION} \
    --add-module=/tmp/ngx_brotli \
    --add-module=/tmp/zstd-nginx-module \
    --add-module=/tmp/headers-more-nginx-module \
    --with-ld-opt='-L/usr/lib' \
    --with-cc-opt=-Wno-error \
    "

# Build and install NGINX
RUN cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure $CONFIG \
    && make -j$(nproc) \
    && make install \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so

# Generate DH parameters
RUN mkdir -p ${CERTS_PREFIX} \
    && openssl dhparam -out ${CERTS_PREFIX}/dhparam.pem.default 4096

# Create GeoIP directory
RUN mkdir -p ${GEOIP_PREFIX}

# Cleanup
RUN apk del .build-deps \
    && rm -rf /tmp/* \
    && rm -rf /usr/src/nginx-$NGINX_VERSION

# Stage 2: Final image
FROM alpine:3.21

# Add metadata
LABEL maintainer="Thomas Spicer (thomas@openbridge.com)"
LABEL org.opencontainers.image.description="NGINX with enhanced modules"
LABEL org.opencontainers.image.licenses="MIT"

# Environment variables
ENV VAR_PREFIX=/var/run \
    LOG_PREFIX=/var/log/nginx \
    TEMP_PREFIX=/tmp \
    CACHE_PREFIX=/var/cache \
    CONF_PREFIX=/etc/nginx \
    CERTS_PREFIX=/etc/pki/tls \
    NGINX_DOCROOT=/usr/share/nginx/html \
    GEOIP_PREFIX=/usr/share/geoip

# Create www-data user
RUN if ! getent group www-data >/dev/null; then \
    addgroup -g 82 -S www-data; \
    fi \
    && if ! getent passwd www-data >/dev/null; then \
    adduser -u 82 -D -S -h /var/cache/nginx -s /sbin/nologin -G www-data www-data; \
    fi

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    gd \
    libgcc \
    libintl \
    libstdc++ \
    libxslt \
    libmaxminddb \
    openssl \
    pcre \
    tini \
    zlib \
    libintl

# Copy files from builder
COPY --from=builder /usr/local/bin/envsubst /usr/local/bin/envsubst
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/share/nginx /usr/share/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder ${CERTS_PREFIX} ${CERTS_PREFIX}
COPY --from=builder ${GEOIP_PREFIX} ${GEOIP_PREFIX}

# Create necessary directories and symlinks
RUN mkdir -p ${LOG_PREFIX} \
    && mkdir -p ${CACHE_PREFIX}/proxy ${CACHE_PREFIX}/fastcgi \
    && mkdir -p /etc/nginx/conf.d \
    && mkdir -p ${NGINX_DOCROOT}/error/ \
    && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
    && ln -sf /dev/stdout ${LOG_PREFIX}/access.log \
    && ln -sf /dev/stderr ${LOG_PREFIX}/error.log \
    && ln -sf /dev/stdout ${LOG_PREFIX}/blocked.log

# Copy configuration files
COPY conf/ /conf
COPY error/ ${NGINX_DOCROOT}/error
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Copy GeoIP databases
COPY geoip/*.mmdb ${GEOIP_PREFIX}/

# Set permissions
RUN chmod +x /docker-entrypoint.sh \
    && chown -R www-data:www-data ${GEOIP_PREFIX}

# Set stop signal
STOPSIGNAL SIGQUIT

# Set entrypoint and CMD
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/env", "bash", "/docker-entrypoint.sh"]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]