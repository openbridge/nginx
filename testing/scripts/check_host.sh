#!/usr/bin/env bash

# This will test to make sure that the upstream prerendering service is operating correctly. Without the service running correctly SEO for the site will be impacted

sleep 10

POST=$(curl -s -S --silent -H "User-Agent: bot" -I https://${NGINX_SERVER_NAME}/ | grep SEO4Ajax )
if [[ ! -z "${POST}" ]]; then
  echo "OK: The SEO4Ajax proxy service is responding correctly to GET requests"
else
  echo "ERROR: The GET requests to the SEO4Ajax proxy service failed" && exit 1
fi
