#!/bin/sh

ENV="${ENVIRONMENT:-dev}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-${ENV}-backend-service}"
BACKEND_URL="http://${BACKEND_SERVICE_NAME}:8000"
RESOLVER=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | grep -v ':' | head -1)

echo "Using BACKEND_URL: $BACKEND_URL"
echo "Using RESOLVER: $RESOLVER"

sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf
sed -i "s|RESOLVER_PLACEHOLDER|${RESOLVER}|g" /etc/nginx/conf.d/default.conf

echo "=== Final nginx config ==="
cat /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"