# Stage 1: Build React app
FROM node:18 as build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

RUN apt-get update && apt-get install curl wget -y && rm -fr /var/lib/apt/lists/*

RUN npm run build

# Stage 2: Serve using nginx

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]