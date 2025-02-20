#!/usr/bin/env bash

#capture first passed variable
FOLDER_PATH=${1}

#capture second passed variable
REFERENCE_SIZE=${2}

#calculate size of folder
SIZE=$(/usr/bin/du -s ${FOLDER_PATH} | /usr/bin/awk '{print $1}')

#convert size to MB
MBSIZE=$((SIZE / 1024))

#provide status code for alert
if [[ ${MBSIZE} -gt $(( ${REFERENCE_SIZE} )) ]]; then
    echo "ERROR: The size of ${FOLDER_PATH} is GREATER than the limit size of ${REFERENCE_SIZE} MB"
    exit 1
  else
    echo "OK: The size of ${FOLDER_PATH} is LESS than the limit size of ${REFERENCE_SIZE} MB"
fi
