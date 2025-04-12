#!/bin/bash
chain="f2b-nginx-forbidden"
while read -r line; do
    if [[ "$line" == *googlebot.com* || "$line" == *cache.google.com* ]]; then
        num=$(echo "$line" | awk '{print $1}')
        echo "Removing rule #$num: $line"
        sudo iptables -D $chain $num
    fi
done < <(sudo iptables -L $chain --line-numbers | grep -nE 'googlebot.com|cache.google.com' | sort -r -n | sed 's/^[0-9]*://')
