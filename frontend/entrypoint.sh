#!/bin/sh

ENV="${ENVIRONMENT:-dev}"
BACKEND_URL="http://${ENV}-backend-service:8000"

echo "Using BACKEND_URL: $BACKEND_URL"

sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"