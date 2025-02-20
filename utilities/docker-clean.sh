#!/usr/bin/env bash

# Remove EVERYTHING!
docker stop $(docker ps -a -q)
docker rm -v $(docker ps -a -q -f status=exited)
docker volume rm $(docker volume ls -qf dangling=true)
docker rmi $(docker images -q)
rm -f wordpress.env wordpress.yml wordpress-login.txt

rm -rf /opt/eff.org/*
rm -rf /etc/letsencrypt/*
rm -rf /etc/letsencrypt

exit 0
