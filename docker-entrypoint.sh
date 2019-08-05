#!/usr/bin/env bash

#---------------------------------------------------------------------
# configure environment
#---------------------------------------------------------------------

function environment() {

# Set the ROOT directory for apps and content
  if [[ -z ${NGINX_DOCROOT} ]]; then NGINX_DOCROOT=/usr/share/nginx/html && export NGINX_DOCROOT && mkdir -p "${NGINX_DOCROOT}"; fi
  if [[ -z ${PHP_FPM_UPSTREAM} ]]; then PHP_FPM_UPSTREAM="localhost:9000;" && export PHP_FPM_UPSTREAM;  fi
  if [[ -z ${NGINX_PROXY_UPSTREAM} ]]; then NGINX_PROXY_UPSTREAM="localhost:8080;" && export NGINX_PROXY_UPSTREAM; fi
  if [[ -z ${REDIS_UPSTREAM} ]]; then REDIS_UPSTREAM="127.0.0.1:6379;" && export REDIS_UPSTREAM; fi

}

#---------------------------------------------------------------------
# setup monit configuration
#---------------------------------------------------------------------

function monit() {

	{
    echo 'set daemon 10'
		echo '    with START DELAY 15'
    echo 'set pidfile /run/monit.pid'
    echo 'set statefile /run/monit.state'
    echo 'set httpd port 2849 and'
    echo '    use address localhost'
    echo '    allow localhost'
    echo 'set logfile syslog'
    echo 'set eventqueue'
    echo '    basedir /var/run'
    echo '    slots 100'
    echo 'include /etc/monit.d/*'
	} | tee /etc/monitrc

	chmod 700 /etc/monitrc
	RUN="monit -c /etc/monitrc" && /usr/bin/env bash -c "${RUN}"

}

#---------------------------------------------------------------------
# set variables
#---------------------------------------------------------------------

function config() {

# Copy the configs to the main nginx and monit conf directories
if [[ ! -z ${NGINX_CONFIG} ]]; then
   if [[ ! -d /conf/${NGINX_CONFIG} ]]; then
      echo "INFO: The NGINX_CONF setting has not been set. Using the default configs..."
    else
      rsync -av --ignore-missing-args /conf/${NGINX_CONFIG}/nginx/* ${CONF_PREFIX}/
      rsync -av --ignore-missing-args /conf/${NGINX_CONFIG}/monit/* /etc/monit.d/
      PAGESPEED_BEACON=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

      # Set the ENV variables in all configs
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_DOCROOT}}|'"${NGINX_DOCROOT}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{CACHE_PREFIX}}|'"${CACHE_PREFIX}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_SERVER_NAME}}|'"${NGINX_SERVER_NAME}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{LOG_PREFIX}}|'"${LOG_PREFIX}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{PAGESPEED_BEACON}}|'"${PAGESPEED_BEACON}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_CDN_HOST}}|'"${NGINX_CDN_HOST}"'|g' {} \;

      # Replace Upstream servers
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{PHP_FPM_UPSTREAM}}|'"${PHP_FPM_UPSTREAM}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_PROXY_UPSTREAM}}|'"${NGINX_PROXY_UPSTREAM}"'|g' {} \;
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{REDIS_UPSTREAM}}|'"${REDIS_UPSTREAM}"'|g' {} \;

      # Replace SPA
      find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_SPA_PRERENDER}}|'"${NGINX_SPA_PRERENDER}"'|g' {} \;

      # Replace monit variables
      find "/etc/monit.d" -maxdepth 3 -type f -exec sed -i -e 's|{{NGINX_DOCROOT}}|'"${NGINX_DOCROOT}"'|g' {} \;
      find "/etc/monit.d" -maxdepth 3 -type f -exec sed -i -e 's|{{CACHE_PREFIX}}|'"${CACHE_PREFIX}"'|g' {} \;
      find "/etc/monit.d" -maxdepth 5 -type f -exec sed -i -e 's|{{NGINX_SERVER_NAME}}|'"${NGINX_SERVER_NAME}"'|g' {} \;
   fi
fi

}

#---------------------------------------------------------------------
# set pernissions for www-data
#---------------------------------------------------------------------

function permissions() {

  find ${NGINX_DOCROOT} ! -user www-data -exec /usr/bin/env bash -c 'i="$1"; chown www-data:www-data "$i"' _ {} \;
  find ${NGINX_DOCROOT} ! -perm 755 -type d -exec /usr/bin/env bash -c 'i="$1"; chmod 755  "$i"' _ {} \;
  find ${NGINX_DOCROOT} ! -perm 644 -type f -exec /usr/bin/env bash -c 'i="$1"; chmod 644 "$i"' _ {} \;
  find ${CACHE_PREFIX} ! -perm 755 -type d -exec /usr/bin/env bash -c 'i="$1"; chmod 755  "$i"' _ {} \;
  find ${CACHE_PREFIX} ! -perm 644 -type f -exec /usr/bin/env bash -c 'i="$1"; chmod 644 "$i"' _ {} \;

}

#---------------------------------------------------------------------
# install self-signed SSL certs for local dev
#---------------------------------------------------------------------

function dev() {

  # Typically these will be mounted via volume, but in case someone
  # needs a dev context this will set the certs so the server will
  # have the basics it needs to run
   if [[ ! -f /etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem ]] || [[ ! -f /etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem ]]; then
     echo "OK: Installing development SSL certificates..."
     mkdir -p /etc/letsencrypt/live/${NGINX_SERVER_NAME}
     /usr/bin/env bash -c "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj /C=US/ST=MA/L=Boston/O=ACMECORP/CN=${NGINX_SERVER_NAME} -keyout /etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem -out /etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem"
     cp /etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem  /etc/letsencrypt/live/${NGINX_SERVER_NAME}/chain.pem
   fi

   # Typically the web apps will be mounted via volume. If it cannot locate those files it throws in test files so the server can prove itself ;)
   if [[ ! -f ${NGINX_DOCROOT}/testing/index.php ]]; then
    echo "OK: Install test PHP and HTML pages to /testing/"
    mkdir -p "${NGINX_DOCROOT}"/testing/
    mkdir -p "${NGINX_DOCROOT}"/error/
    rsync -av --ignore-missing-args /tmp/test/* ${NGINX_DOCROOT}/testing/
    rsync -av --ignore-missing-args /tmp/error/* ${NGINX_DOCROOT}/error/
   fi
}

#---------------------------------------------------------------------
# install bad bot protection
#---------------------------------------------------------------------

function bots() {
    # https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
    mkdir -p /etc/nginx/sites-available
    # Change the install direcotry:
    cd /usr/sbin || exit
    # Download the config, install and update applications
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O install-ngxblocker
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/setup-ngxblocker -O setup-ngxblocker
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/update-ngxblocker -O update-ngxblocker
    # Set permissions
    chmod +x install-ngxblocker
    chmod +x setup-ngxblocker
    chmod +x update-ngxblocker
    # Run installer and configuration
    install-ngxblocker -x
    setup-ngxblocker -x -w ${NGINX_DOCROOT}
    echo "OK: Clean up variables..."
    sed -i -e 's|^variables_hash_max_|#variables_hash_max_|g' /etc/nginx/conf.d/botblocker-nginx-settings.conf
}

#---------------------------------------------------------------------
# configure SSL
#---------------------------------------------------------------------

function openssl() {

  # The first argument is the bit depth of the dhparam, or 2048 if unspecified
  DHPARAM_BITS=${1:-2048}

  # If a dhparam file is not available, use the pre-generated one and generate a new one in the background.
  PREGEN_DHPARAM_FILE=${CERTS_PREFIX}/dhparam.pem.default
  DHPARAM_FILE=${CERTS_PREFIX}/dhparam.pem
  GEN_LOCKFILE=/tmp/dhparam_generating.lock

  if [[ ! -f ${PREGEN_DHPARAM_FILE} ]]; then
     echo "OK: NO PREGEN_DHPARAM_FILE is present. Generate ${PREGEN_DHPARAM_FILE}..."
     nice -n +5 openssl dhparam -out ${DHPARAM_FILE} 2048 2>&1
  fi

  if [[ ! -f ${DHPARAM_FILE} ]]; then
     # Put the default dhparam file in place so we can start immediately
     echo "OK: NO DHPARAM_FILE present. Copy ${PREGEN_DHPARAM_FILE} to ${DHPARAM_FILE}..."
     cp ${PREGEN_DHPARAM_FILE} ${DHPARAM_FILE}
     touch ${GEN_LOCKFILE}

     # The hash of the pregenerated dhparam file is used to check if the pregen dhparam is already in use
     PREGEN_HASH=$(md5sum ${PREGEN_DHPARAM_FILE} | cut -d" " -f1)
     CURRENT_HASH=$(md5sum ${DHPARAM_FILE} | cut -d" " -f1)
     if [[ "${PREGEN_HASH}" != "${CURRENT_HASH}" ]]; then
      # Generate a new dhparam in the background in a low priority and reload nginx when finished (grep removes the progress indicator).
     (
         (
             nice -n +5 openssl dhparam -out ${DHPARAM_FILE} ${DHPARAM_BITS} 2>&1 \
         ) | grep -vE '^[\.+]+'
         rm ${GEN_LOCKFILE}
     ) &disown
    fi
  fi

# Add Let's Encrypt CA in case it is needed
  mkdir -p /etc/ssl/private
  cd /etc/ssl/private || exit
  wget -O - https://letsencrypt.org/certs/isrgrootx1.pem https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem https://letsencrypt.org/certs/letsencryptauthorityx1.pem https://www.identrust.com/certificates/trustid/root-download-x3.html | tee -a ca-certs.pem> /dev/null

}

#---------------------------------------------------------------------
# install CDN
#---------------------------------------------------------------------

function cdn () {
{
    echo 'location ~* \.(gif|png|jpg|jpeg|svg)$ {'
    echo '   return  301 https://{{NGINX_CDN_HOST}}$request_uri;'
		echo '}'
} | tee /etc/nginx/conf.d/cdn.conf

}

#---------------------------------------------------------------------
# start everything up
#---------------------------------------------------------------------

function run() {
   environment
   openssl
   if [[ -z ${NGINX_CDN_HOST} ]]; then echo "CDN was not set"; else cdn; fi
   config
   if [[ ${NGINX_BAD_BOTS} = "true" ]]; then bots; else echo "BOTS was not set"; fi
   if [[ ${NGINX_DEV_INSTALL} = "true" ]]; then dev; fi
   #permissions
   if [[ ${NGINX_CONFIG} != "basic" ]]; then monit; fi
}

run

exec "$@"
