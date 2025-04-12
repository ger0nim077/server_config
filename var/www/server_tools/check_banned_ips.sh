# Unban all Googlebot IPs by resolving hostnames
for host in \
  crawl-66-249-79-35.googlebot.com \
  crawl-66-249-79-34.googlebot.com \
  crawl-66-249-79-1.googlebot.com \
  crawl-66-249-77-69.googlebot.com \
  crawl-66-249-77-160.googlebot.com \
  crawl-66-249-71-64.googlebot.com \
  crawl-66-249-66-199.googlebot.com \
  crawl-66-249-66-198.googlebot.com \
  crawl-66-249-66-197.googlebot.com \
  crawl-66-249-65-65.googlebot.com \
  crawl-66-249-65-38.googlebot.com \
  crawl-66-249-65-37.googlebot.com \
  crawl-66-249-64-130.googlebot.com \
  crawl-66-249-64-129.googlebot.com \
  crawl-66-249-64-128.googlebot.com \
  cache.google.com; do

    ip=$(host $host | awk '/has address/ { print $4 }')
    if [ ! -z "$ip" ]; then
        echo "Unbanning $host ($ip)"
        sudo iptables -D f2b-nginx-forbidden -s "$ip" -j REJECT
        sudo iptables -D f2b-SSH -s "$ip" -j REJECT 2>/dev/null
    fi
done
