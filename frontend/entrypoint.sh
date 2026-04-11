#!/bin/sh

ENV="${ENVIRONMENT:-dev}"
ECS_NAMESPACE="${ECS_NAMESPACE:-${ENV}-jobgpt}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-${ENV}-backend-service}"
BACKEND_URL="${BACKEND_URL:-http://${BACKEND_SERVICE_NAME}:8000}"
RESOLVER=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)

echo "Using BACKEND_URL: $BACKEND_URL"
echo "Using ECS_NAMESPACE: $ECS_NAMESPACE"
echo "Using BACKEND_SERVICE_NAME: $BACKEND_SERVICE_NAME"
echo "Using RESOLVER: $RESOLVER"

sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf
sed -i "s|RESOLVER_PLACEHOLDER|${RESOLVER}|g" /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"