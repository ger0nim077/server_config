#!/bin/bash
echo "Checking if IPs are still banned in iptables..."
while read ip; do
    if sudo iptables -L -n | grep -q "$ip"; then
        echo "$ip is STILL BANNED"
    else
        echo "$ip is NOT currently banned"
    fi
done < iptables.txt
