#!/bin/bash
echo "Checking IPs against current iptables bans..."
while read ip; do
    if sudo iptables -L -n | grep -q -w "$ip"; then
        echo "$ip IS CURRENTLY BANNED ❌"
    else
        echo "$ip is NOT currently banned ✅"
    fi
done < "/var/www/server_tools/iptables.txt"
