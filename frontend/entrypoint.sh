#!/bin/sh

ENV="${ENVIRONMENT:-dev}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-${ENV}-backend-service}"

# Get IPv4 address from /etc/hosts (Service Connect injects 127.255.x.x)
BACKEND_IP=$(grep "$BACKEND_SERVICE_NAME" /etc/hosts | grep -v ':' | awk '{print $1}' | head -1)

if [ -n "$BACKEND_IP" ]; then
  BACKEND_URL="http://${BACKEND_IP}:8000"
  echo "Using backend IP from /etc/hosts: $BACKEND_URL"
else
  # Fallback to service name if not found
  BACKEND_URL="http://${BACKEND_SERVICE_NAME}:8000"
  echo "Backend not in /etc/hosts, using: $BACKEND_URL"
fi

echo "=== Replacing placeholders ==="
sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf

echo "=== Final nginx config ==="
cat /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"