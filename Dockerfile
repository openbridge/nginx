# Use Alpine Linux 3.20 as the base image for its small size and security
FROM alpine:3.20

# Metadata for the image
LABEL maintainer="Thomas Spicer (thomas@openbridge.com)"

# Build-time argument for NGINX version
ARG NGINX_VERSION

# Set environment variables for various directory paths
ENV VAR_PREFIX=/var/run \
    LOG_PREFIX=/var/log/nginx \
    TEMP_PREFIX=/tmp \
    CACHE_PREFIX=/var/cache \
    CONF_PREFIX=/etc/nginx \
    CERTS_PREFIX=/etc/pki/tls

# Main build process
RUN set -x  \
  # NGINX configuration options
  && CONFIG="\
    --prefix=/usr/share/nginx/ \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=${CONF_PREFIX}/nginx.conf \
    --error-log-path=${LOG_PREFIX}/error.log \
    --http-log-path=${LOG_PREFIX}/access.log \
    --pid-path=${VAR_PREFIX}/nginx.pid \
    --lock-path=${VAR_PREFIX}/nginx.lock \
    --http-client-body-temp-path=${TEMP_PREFIX}/client_temp \
    --http-proxy-temp-path=${TEMP_PREFIX}/proxy_temp \
    --http-fastcgi-temp-path=${TEMP_PREFIX}/fastcgi_temp \
    --http-uwsgi-temp-path=${TEMP_PREFIX}/uwsgi_temp \
    --http-scgi-temp-path=${TEMP_PREFIX}/scgi_temp \
    --user=www-data \
    --group=www-data \
    --with-http_ssl_module \
    --with-pcre-jit \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
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
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
    --add-module=/tmp/ngx_cache_purge-2.3 \
    --add-module=/tmp/ngx_http_redis-0.4.1-cmm \
    --add-module=/tmp/redis2-nginx-module-0.15 \
    --add-module=/tmp/srcache-nginx-module-0.33 \
    --add-module=/tmp/echo-nginx-module \
    --add-module=/tmp/ngx_devel_kit-0.3.2 \
    --add-module=/tmp/set-misc-nginx-module-0.33 \
    --add-module=/tmp/ngx_brotli \
    --with-ld-opt='-L/usr/lib' \
    --with-cc-opt=-Wno-error \
  " \
  # Create www-data user and group if they don't exist
  && if [ -z "$(getent group www-data)" ]; then addgroup -g 82 -S www-data; fi \
  && if [ -z "$(getent passwd www-data)" ]; then adduser -u 82 -D -S -h /var/cache/nginx -s /sbin/nologin -G www-data www-data; fi \
  # Install build dependencies
  && apk add --no-cache --virtual .build-deps \
      alpine-sdk \
      autoconf \
      automake \
      binutils  \
      build-base  \
      build-base \
      ca-certificates \
      cmake  \
      findutils \
      gcc  \
      gd-dev \
      gettext \
      git \
      gnupg  \
      gnupg \
      go  \
      gzip \
      libc-dev \
      libtool  \
      libxslt-dev \
      linux-headers \
      libedit-dev \
      make \
      musl-dev \
      openssl-dev \
      pcre-dev \
      perl-dev \
      unzip \
      wget \
      zlib-dev \
  && apk add --no-cache --update \
      curl \
      monit \
      wget \
      bash \
      bind-tools \
      rsync \
      openssl \
      pcre \
      tini \
      tar \
  # Clone and prepare ngx_brotli module
  && cd /tmp \
  && git clone https://github.com/google/ngx_brotli --depth=1 \
  && cd ngx_brotli && git submodule update --init \
  && export NGX_BROTLI_STATIC_MODULE_ONLY=1 \
  # Download and extract NGINX source
  && cd /tmp \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
  && mkdir -p /usr/src \
  && tar -zxC /usr/src -f nginx.tar.gz \
  && rm nginx.tar.gz \
  # Download and extract additional NGINX modules
  && cd /tmp \
  && git clone https://github.com/openresty/echo-nginx-module.git \
  && wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.2.zip -O dev.zip \
  && wget https://github.com/openresty/set-misc-nginx-module/archive/refs/tags/v0.33.zip -O setmisc.zip \
  && wget https://github.com/centminmod/ngx_http_redis/archive/refs/tags/0.4.1-cmm.zip -O ngx.zip \
  && wget https://github.com/openresty/redis2-nginx-module/archive/refs/tags/v0.15.zip -O redis.zip \
  && wget https://github.com/openresty/srcache-nginx-module/archive/refs/tags/v0.33.zip -O cache.zip \
  && wget https://github.com/FRiCKLE/ngx_cache_purge/archive/refs/tags/2.3.zip -O purge.zip \
  && unzip ngx.zip \
  && unzip dev.zip \
  && unzip setmisc.zip \
  && unzip redis.zip \
  && unzip cache.zip \
  && unzip purge.zip \
  # Configure and build NGINX with debug symbols
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure $CONFIG --with-debug \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && mv objs/nginx objs/nginx-debug \
  && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
  && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
  # Configure and build release version of NGINX
  && ./configure $CONFIG \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  # Set up NGINX directories and files
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 html/index.html /usr/share/nginx/html/ \
  && install -m644 html/50x.html /usr/share/nginx/html/ \
  && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
  && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
  && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
  # Strip debug symbols to reduce binary size
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  # Create necessary directories
  && mkdir -p /usr/local/bin/ /usr/local/sbin/ \
  && mkdir -p ${CACHE_PREFIX} \
  && mkdir -p ${CERTS_PREFIX} \
  # Handle envsubst installation
  && mv /usr/bin/envsubst /tmp/ \
  && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
  && apk add --no-cache $runDeps \
  && mv /tmp/envsubst /usr/local/bin/ \
  # Generate DH parameters for SSL
  && cd /etc/pki/tls/ \
  && nice -n +5 openssl dhparam -out /etc/pki/tls/dhparam.pem.default 2048 \
  # Clean up
  && apk del .build-deps \
  # Set up log symlinks for Docker log collection
  && ln -sf /dev/stdout ${LOG_PREFIX}/access.log \
  && ln -sf /dev/stderr ${LOG_PREFIX}/error.log \
  && ln -sf /dev/stdout ${LOG_PREFIX}/blocked.log

# Copy configuration files and scripts
COPY conf/ /conf
COPY test/ /tmp/test
COPY error/ /tmp/error/
COPY check_wwwdata.sh /usr/bin/check_wwwdata
COPY check_folder.sh /usr/bin/check_folder
COPY check_host.sh /usr/bin/check_host
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set execute permissions on scripts
RUN chmod +x /docker-entrypoint.sh /usr/bin/check_wwwdata /usr/bin/check_folder /usr/bin/check_host

# Set the stop signal for graceful shutdown
STOPSIGNAL SIGQUIT

# Set the entrypoint script to be run on container start
ENTRYPOINT ["/usr/bin/env", "bash", "/docker-entrypoint.sh"]

# Set the default command
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]