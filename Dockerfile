FROM alpine:3.8
MAINTAINER Thomas Spicer (thomas@openbridge.com)

ENV NGINX_VERSION=1.15.2 \
    VAR_PREFIX=/var/run \
    LOG_PREFIX=/var/log/nginx \
    MOD_PAGESPEED_VER=1.13.35.2 \
    NGX_PAGESPEED_VER=1.13.35.2 \
    TEMP_PREFIX=/tmp \
    CACHE_PREFIX=/var/cache \
    CONF_PREFIX=/etc/nginx \
    CERTS_PREFIX=/etc/pki/tls/

COPY psol/ /tmp
RUN set -x  \
  && addgroup -g 82 -S www-data \
  && adduser -u 82 -D -S -h /var/cache/nginx -s /sbin/nologin -G www-data www-data \
  && echo -e '@community http://nl.alpinelinux.org/alpine/3.8/community' >> /etc/apk/repositories \
  && apk add --no-cache --virtual .build-deps \
      build-base \
      findutils \
      apr-dev \
      apr-util-dev \
      apache2-dev \
      gnupg \
      gperf \
      icu-dev \
      gettext-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      libtool \
      ca-certificates \
      automake \
      autoconf \
      git \
      jemalloc-dev \
      libtool \
      binutils \
      gnupg \
      cmake \
      go \
      gcc \
      build-base \
      libc-dev \
      make \
      wget \
      gzip \
      libressl-dev \
      musl-dev \
      pcre-dev \
      zlib-dev \
      geoip-dev \
      git \
      linux-headers \
      libxslt-dev \
      nghttp2 \
      gd-dev \
      unzip \
  && apk add --no-cache --update \
      curl \
      monit \
      bash \
      bind-tools \
      rsync \
      geoip \
      libressl \
      tini \
      tar \
  && cd /tmp \
  && git clone https://github.com/google/ngx_brotli --depth=1 \
  && cd ngx_brotli && git submodule update --init \
  && export NGX_BROTLI_STATIC_MODULE_ONLY=1 \
  && cd /tmp \
  && git clone https://github.com/nbs-system/naxsi.git \
  && echo 'adding /usr/local/share/GeoIP/GeoIP.dat database' \
  && wget -N http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz \
  && wget -N http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz \
  && gunzip GeoIP.dat.gz \
  && gunzip GeoLiteCity.dat.gz \
  && mkdir /usr/local/share/GeoIP/ \
  && mv GeoIP.dat /usr/local/share/GeoIP/ \
  && mv GeoLiteCity.dat /usr/local/share/GeoIP/ \
  && chown -R www-data:www-data /usr/local/share/GeoIP/ \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
  && mkdir -p /usr/src \
  && tar -zxC /usr/src -f nginx.tar.gz \
  && rm nginx.tar.gz \
  && cd /tmp \
  && git clone -b "v${NGX_PAGESPEED_VER}-stable" \
    --recurse-submodules \
    --shallow-submodules \
    --depth=1 \
    -c advice.detachedHead=false \
    -j$(getconf _NPROCESSORS_ONLN) \
    https://github.com/apache/incubator-pagespeed-ngx.git \
    /tmp/ngxpagespeed \
   \
  #&& psolurl="https://github.com/wodby/nginx-alpine-psol/releases/download/${MOD_PAGESPEED_VER}/psol.tar.gz" \
  #&& wget -qO- "${psolurl}" | tar xz -C /tmp/ngxpagespeed \
  && cd /tmp \
  && tar -zxC /tmp/ngxpagespeed -f psol.tar.gz \
  && git clone https://github.com/openresty/echo-nginx-module.git \
  && wget https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.zip -O dev.zip \
  && wget https://github.com/openresty/set-misc-nginx-module/archive/v0.31.zip -O setmisc.zip \
  && wget https://people.freebsd.org/~osa/ngx_http_redis-0.3.8.tar.gz \
  && wget https://github.com/openresty/redis2-nginx-module/archive/v0.14.zip -O redis.zip \
  && wget https://github.com/openresty/srcache-nginx-module/archive/v0.31.zip -O cache.zip \
  && wget https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.zip -O purge.zip \
  && tar -zx -f ngx_http_redis-0.3.8.tar.gz \
  && unzip dev.zip \
  && unzip setmisc.zip \
  && unzip redis.zip \
  && unzip cache.zip \
  && unzip purge.zip \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure \
    --prefix=/usr/share/nginx/ \
    --sbin-path=/usr/sbin/nginx \
    --add-module=/tmp/naxsi/naxsi_src \
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
    --with-file-aio \
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
    --with-http_geoip_module=dynamic \
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
    --with-http_v2_module \
    --with-ld-opt="-Wl,-z,relro,--start-group -lapr-1 -laprutil-1 -licudata -licuuc -lpng -lturbojpeg -ljpeg" \
    --add-module=/tmp/ngx_cache_purge-2.3 \
    --add-module=/tmp/ngx_http_redis-0.3.8 \
    --add-module=/tmp/redis2-nginx-module-0.14 \
    --add-module=/tmp/srcache-nginx-module-0.31 \
    --add-module=/tmp/echo-nginx-module \
    --add-module=/tmp/ngx_devel_kit-0.3.0 \
    --add-module=/tmp/set-misc-nginx-module-0.31 \
    --add-module=/tmp/ngx_brotli \
    --add-module=/tmp/ngxpagespeed \
  \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && mv objs/nginx objs/nginx-debug \
  && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
  && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
  && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
  && ./configure \
    --prefix=/usr/share/nginx/ \
    --sbin-path=/usr/sbin/nginx \
    --add-module=/tmp/naxsi/naxsi_src \
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
    --with-file-aio \
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
    --with-http_geoip_module=dynamic \
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
    --with-http_v2_module \
    --with-ld-opt="-Wl,-z,relro,--start-group -lapr-1 -laprutil-1 -licudata -licuuc -lpng -lturbojpeg -ljpeg" \
    --add-module=/tmp/ngx_cache_purge-2.3 \
    --add-module=/tmp/ngx_http_redis-0.3.8 \
    --add-module=/tmp/redis2-nginx-module-0.14 \
    --add-module=/tmp/srcache-nginx-module-0.31 \
    --add-module=/tmp/echo-nginx-module \
    --add-module=/tmp/ngx_devel_kit-0.3.0 \
    --add-module=/tmp/set-misc-nginx-module-0.31 \
    --add-module=/tmp/ngx_brotli \
    --add-module=/tmp/ngxpagespeed \
  \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir -p /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 html/index.html /usr/share/nginx/html/ \
  && install -m644 html/50x.html /usr/share/nginx/html/ \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && mkdir -p /usr/local/bin/ \
  && mkdir -p ${CACHE_PREFIX} \
  && mkdir -p ${CERTS_PREFIX} \
  && cd ${CERTS_PREFIX} \
  && openssl dhparam 2048 -out ${CERTS_PREFIX}/dhparam.pem.default \
  && apk add --no-cache --virtual .gettext gettext \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
    scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
  )" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk del .build-deps \
  && apk del .gettext \
  && cd /tmp/naxsi \
  && mv naxsi_config/naxsi_core.rules /etc/nginx/naxsi_core.rules \
  && mv /tmp/envsubst /usr/local/bin/ \
  && rm -rf /tmp/* \
  && rm -rf /usr/src/* \
  && ln -sf /dev/stdout ${LOG_PREFIX}/access.log \
  && ln -sf /dev/stderr ${LOG_PREFIX}/error.log \
  && ln -sf /dev/stdout ${LOG_PREFIX}/blocked.log

COPY conf/ /conf
COPY test/ /tmp/test
COPY error/ /tmp/error/
COPY check_wwwdata.sh /usr/bin/check_wwwdata
COPY check_folder.sh /usr/bin/check_folder
COPY check_host.sh /usr/bin/check_host
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh /usr/bin/check_wwwdata /usr/bin/check_folder /usr/bin/check_host

STOPSIGNAL SIGQUIT
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
