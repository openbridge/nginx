#!/usr/bin/env bash

function permission() {

if [[ $(find ${NGINX_DOCROOT} ! -perm 755 -type d | wc -l) -gt 0 ]] || [[ $(find ${NGINX_DOCROOT} ! -perm 644 -type f | wc -l) -gt 0 ]]; then
    echo "ERROR: There are permissions issues with directories and/or files within ${NGINX_DOCROOT}"
    /usr/bin/env bash -c 'find {{NGINX_DOCROOT}} -type d -exec chmod 755 {} \; && find {{NGINX_DOCROOT}} -type f -exec chmod 644 {} \;'
 else
    echo "OK: Permissions 755 (dir) and 644 (files) look correct on ${NGINX_DOCROOT}"
fi

}

function owner() {

if [[ $(find ${NGINX_DOCROOT} ! -user www-data | wc -l) -gt 0 ]]; then
    echo "ERROR: Incorrect user:group are set within ${NGINX_DOCROOT}"
    /usr/bin/env bash -c 'find /usr/share/nginx/html -type d -exec chown www-data:www-data {} \; && find {{NGINX_DOCROOT}} -type f -exec chown www-data:www-data {} \;'
 else
    echo "OK: www-date (user:group) ownership looks corect on ${NGINX_DOCROOT}"
fi

}

"$@"
