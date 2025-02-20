#!/usr/bin/env bash

environment() {
  # Set the ROOT directory for apps and content
  if [[ -z "${NGINX_DOCROOT}" ]]; then
    NGINX_DOCROOT="/usr/share/nginx/html"
    export NGINX_DOCROOT
    mkdir -p "${NGINX_DOCROOT}" || {
      echo "ERROR: Failed to create directory ${NGINX_DOCROOT}" >&2
      return 1
    }
    echo "INFO: NGINX_DOCROOT set to ${NGINX_DOCROOT}"
  fi

  if [[ -z "${PHP_FPM_UPSTREAM_HOST}" ]]; then
    PHP_FPM_UPSTREAM_HOST="localhost"
    PHP_FPM_UPSTREAM_PORT="9000"
    export PHP_FPM_UPSTREAM_HOST
    export PHP_FPM_UPSTREAM_PORT
    echo "INFO: PHP_FPM_UPSTREAM_HOST set to ${PHP_FPM_UPSTREAM_HOST}:${PHP_FPM_UPSTREAM_PORT}"
  fi

  if [[ -z "${NGINX_PROXY_UPSTREAM}" ]]; then
    NGINX_PROXY_UPSTREAM="localhost:8080;"
    export NGINX_PROXY_UPSTREAM
    echo "INFO: NGINX_PROXY_UPSTREAM set to ${NGINX_PROXY_UPSTREAM}"
  fi

  if [[ -z "${REDIS_UPSTREAM_HOST}" ]]; then
    REDIS_UPSTREAM_HOST="localhost:6379;"
    export REDIS_UPSTREAM_HOST
    echo "INFO: REDIS_UPSTREAM_HOST set to ${REDIS_UPSTREAM_HOST}"
  fi
}

config() {
  # Copy the configs to the main nginx and monit conf directories
  if [[ -n "${NGINX_CONFIG}" ]]; then
    local config_dir="/conf/${NGINX_CONFIG}"

    if [[ ! -d "${config_dir}" ]]; then
      echo "INFO: The NGINX_CONF setting is not valid. Using the default configs..."
      return 1
    fi

    echo "INFO: Copying configuration files from ${config_dir} to ${CONF_PREFIX}..."

    if ! cp -r "${config_dir}/nginx/." "${CONF_PREFIX}/"; then
      echo "ERROR: Failed to copy configuration files."
      return 1
    fi

    echo "INFO: Replacing placeholders in configuration files..."
    find "${CONF_PREFIX}" -maxdepth 5 -type f -exec sed -i -e \
      "s|{{NGINX_DOCROOT}}|${NGINX_DOCROOT}|g" \
      -e "s|{{CACHE_PREFIX}}|${CACHE_PREFIX}|g" \
      -e "s|{{NGINX_SERVER_NAME}}|${NGINX_SERVER_NAME}|g" \
      -e "s|{{LOG_PREFIX}}|${LOG_PREFIX}|g" \
      -e "s|{{NGINX_CDN_HOST}}|${NGINX_CDN_HOST}|g" \
      -e "s|{{PHP_FPM_UPSTREAM_HOST}}|${PHP_FPM_UPSTREAM_HOST}|g" \
      -e "s|{{PHP_FPM_UPSTREAM_PORT}}|${PHP_FPM_UPSTREAM_PORT}|g" \
      -e "s|{{NGINX_PROXY_UPSTREAM}}|${NGINX_PROXY_UPSTREAM}|g" \
      -e "s|{{REDIS_UPSTREAM_HOST}}|${REDIS_UPSTREAM_HOST}|g" \
      -e "s|{{REDIS_UPSTREAM_PORT}}|${REDIS_UPSTREAM_PORT}|g" {} +

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Failed to replace placeholders in configuration files."
      return 1
    fi

    echo "INFO: Configuration files processed successfully."
  else
    echo "INFO: NGINX_CONFIG is not set. Skipping configuration."
  fi
}

permissions() {
  echo "Setting permissions for ${NGINX_DOCROOT}..."

  mkdir -p /var/cache/fastcgi /var/cache/proxy /var/cache/fastcgi_temp

  chown -R www-data:www-data "${NGINX_DOCROOT}"

  echo "Setting directory permissions..."
  find "${NGINX_DOCROOT}" -type d -exec chmod 755 {} +
  find "${CACHE_PREFIX}" -type d -exec chmod 755 {} +

  echo "Setting file permissions..."
  find "${NGINX_DOCROOT}" -type f -exec chmod 644 {} +
  find "${CACHE_PREFIX}" -type f -exec chmod 644 {} +

  echo "Permissions update complete"
}

dev() {
  # Typically these will be mounted via volume, but in case someone
  # needs a dev context this will set the certs so the server will
  # have the basics it needs to run
  if [[ ! -f "/etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem" ]] || [[ ! -f "/etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem" ]]; then
    echo "OK: Installing development SSL certificates..."
    mkdir -p "/etc/letsencrypt/live/${NGINX_SERVER_NAME}"
    /usr/bin/env bash -c "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj /C=US/ST=MA/L=Boston/O=ACMECORP/CN=${NGINX_SERVER_NAME} -keyout \"/etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem\" -out \"/etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem\""
    cp "/etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem" "/etc/letsencrypt/live/${NGINX_SERVER_NAME}/chain.pem"
  fi
}

bots() {
  mkdir -p /etc/nginx/conf.d /etc/nginx/bots.d /usr/local/sbin

  base_url="https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master"

  declare -A paths=(
    ["$base_url/conf.d/globalblacklist.conf"]="/etc/nginx/conf.d/globalblacklist.conf"
    ["$base_url/bots.d/blockbots.conf"]="/etc/nginx/bots.d/blockbots.conf"
    ["$base_url/bots.d/ddos.conf"]="/etc/nginx/bots.d/ddos.conf"
    ["$base_url/bots.d/blacklist-user-agents.conf"]="/etc/nginx/bots.d/blacklist-user-agents.conf"
    ["$base_url/bots.d/custom-bad-referrers.conf"]="/etc/nginx/bots.d/custom-bad-referrers.conf"
    ["$base_url/bots.d/blacklist-ips.conf"]="/etc/nginx/bots.d/blacklist-ips.conf"
    ["$base_url/bots.d/bad-referrer-words.conf"]="/etc/nginx/bots.d/bad-referrer-words.conf"
    ["$base_url/conf.d/botblocker-nginx-settings.conf"]="/etc/nginx/conf.d/botblocker-nginx-settings.conf"
    ["$base_url/install-ngxblocker"]="/usr/local/sbin/install-ngxblocker"
    ["$base_url/update-ngxblocker"]="/usr/local/sbin/update-ngxblocker"
  )

  for url in "${!paths[@]}"; do
    wget -O "${paths[$url]}" "$url" || {
      echo "Failed to download $url"
      exit 1
    }
  done

  chmod +x /usr/local/sbin/install-ngxblocker /usr/local/sbin/update-ngxblocker

  /usr/local/sbin/update-ngxblocker -c /etc/nginx/conf.d -b /etc/nginx/bots.d
  sed -i -e 's|^variables_hash_max_|#variables_hash_max_|g' /etc/nginx/conf.d/botblocker-nginx-settings.conf

  CRON_JOB="30 0 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx/conf.d -b /etc/nginx/bots.d -i /usr/local/sbin"
  (crontab -l 2>/dev/null | grep -Fq "$CRON_JOB") || (
    crontab -l 2>/dev/null
    echo "$CRON_JOB"
  ) | crontab -

  echo "Setup complete."
}

openssl() {
  local DHPARAM_BITS="${1:-2048}"

  # If a dhparam file is not available, use the pre-generated one and generate a new one in the background.
  local PREGEN_DHPARAM_FILE="${CERTS_PREFIX}/dhparam.pem.default"
  local DHPARAM_FILE="${CERTS_PREFIX}/dhparam.pem"
  local GEN_LOCKFILE="/tmp/dhparam_generating.lock"

  if [[ ! -f "${PREGEN_DHPARAM_FILE}" ]]; then
    echo "OK: NO PREGEN_DHPARAM_FILE is present. Generate ${PREGEN_DHPARAM_FILE}..."
    nice -n +5 openssl dhparam -out "${DHPARAM_FILE}" 2048 2>&1
  fi

  if [[ ! -f "${DHPARAM_FILE}" ]]; then
    # Put the default dhparam file in place so we can start immediately
    echo "OK: NO DHPARAM_FILE present. Copy ${PREGEN_DHPARAM_FILE} to ${DHPARAM_FILE}..."
    cp "${PREGEN_DHPARAM_FILE}" "${DHPARAM_FILE}"
    touch "${GEN_LOCKFILE}"

    # The hash of the pregenerated dhparam file is used to check if the pregen dhparam is already in use
    local PREGEN_HASH
    PREGEN_HASH=$(md5sum "${PREGEN_DHPARAM_FILE}" | cut -d" " -f1)
    local CURRENT_HASH
    CURRENT_HASH=$(md5sum "${DHPARAM_FILE}" | cut -d" " -f1)
    if [[ "${PREGEN_HASH}" != "${CURRENT_HASH}" ]]; then
      # Generate a new dhparam in the background in a low priority and reload nginx when finished (grep removes the progress indicator).
      (
        (
          nice -n +5 openssl dhparam -out "${DHPARAM_FILE}" "${DHPARAM_BITS}" 2>&1
        ) | grep -vE '^[\.+]+'
        rm "${GEN_LOCKFILE}"
      ) &
      disown
    fi
  fi

  # Add Let's Encrypt CA in case it is needed
  mkdir -p /etc/ssl/private /var/cache/proxy
  cd /etc/ssl/private || exit
  wget -O - https://letsencrypt.org/certs/isrgrootx1.pem \
    https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem \
    https://letsencrypt.org/certs/letsencryptauthorityx1.pem \
    https://www.identrust.com/certificates/trustid/root-download-x3.html | tee -a ca-certs.pem >/dev/null
}

cdn() {
  local cdn_conf="/etc/nginx/conf.d/cdn.conf"

  # Check if NGINX_CDN_HOST is set
  if [[ -z "${NGINX_CDN_HOST}" ]]; then
    echo "ERROR: NGINX_CDN_HOST is not set. Cannot create CDN configuration." >&2
    return 1
  fi

  echo "INFO: Creating CDN configuration at ${cdn_conf}..."

  # Write the CDN configuration
  {
    echo 'location ~* \.(gif|png|jpg|jpeg|svg)$ {'
    echo "   return 301 https://${NGINX_CDN_HOST}\$request_uri;"
    echo '}'
  } >"${cdn_conf}"

  # Verify that the configuration was written successfully
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to write CDN configuration to ${cdn_conf}." >&2
    return 1
  fi

  echo "INFO: CDN configuration successfully written to ${cdn_conf}."
}

run() {
  # Environment setup
  openssl "$@"
  if [[ -z ${NGINX_CDN_HOST} ]]; then echo "CDN was not set"; else cdn; fi
  config
  if [[ ${NGINX_BAD_BOTS} = "true" ]]; then bots; else echo "BOTS was not set"; fi
  if [[ ${NGINX_DEV_INSTALL} = "true" ]]; then dev; fi
  permissions
}

# Ensure run is called with arguments if needed
run "$@"

# Execute the passed command
if [[ $# -eq 0 ]]; then
  echo "No command provided for exec."
else
  exec "$@"
fi