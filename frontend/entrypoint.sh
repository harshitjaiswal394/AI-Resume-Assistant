#!/bin/sh

ENV="${ENVIRONMENT:-dev}"
ECS_NAMESPACE="${ECS_NAMESPACE:-${ENV}-jobgpt}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-${ENV}-backend-service}"
BACKEND_URL="${BACKEND_URL:-http://${BACKEND_SERVICE_NAME}:8000}"

echo "Using BACKEND_URL: $BACKEND_URL"
echo "Using ECS_NAMESPACE: $ECS_NAMESPACE"
echo "Using BACKEND_SERVICE_NAME: $BACKEND_SERVICE_NAME"

sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
