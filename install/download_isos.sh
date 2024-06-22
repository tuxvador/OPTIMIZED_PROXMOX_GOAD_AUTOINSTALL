#!/bin/bash

declare -A urls
declare -A names

while IFS='=' read -r key value; do
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')
    case $key in
        WIN_10_NAME|WIN_SRV_2016_NAME|WIN_SRV_2019_NAME|PFSENSE_ISO_NAME)
            names[$key]=$value
            ;;
        WIN_10_URL|WIN_SRV_2016_URL|WIN_SRV_2019_URL|PFSENSE_ISO_URL)
            urls[$key]=$value
            ;;
    esac
done < goad.conf

for key in "${!names[@]}"; do
    name=${names[$key]}
    url_key=${key/_NAME/_URL}
    url=${urls[$url_key]}
    wget -nc -O /var/lib/vz/template/iso/$name $url
done

if [ -n "${urls[PFSENSE_ISO_URL]}" ]; then
    gz_path="/var/lib/vz/template/iso/${names[PFSENSE_ISO_NAME]}"
    iso_path="${gz_path%.gz}"  # Remove .gz extension for the ISO file path
    wget -nc -O "$gz_path" ${urls[PFSENSE_ISO_URL]}
    if [ ! -f "$iso_path" ]; then
        gzip -d "$gz_path"
    fi
fi
