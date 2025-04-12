#!/bin/bash
while read host; do
    ip=$(host "$host" | awk '/has address/ { print $4 }')
    if [[ $ip ]]; then
        echo "$host resolves to $ip"
    else
        echo "$host could not be resolved"
    fi
done < "/var/www/server_tools/iptables.txt"
