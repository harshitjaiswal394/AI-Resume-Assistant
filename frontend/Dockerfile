# Stage 1: Build React app
FROM node:18 as build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY . .

RUN apt-get update && apt-get install curl wget -y && rm -fr /var/lib/apt/lists/*

RUN npm run build

# Stage 2: Serve using nginx

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html

# The official nginx image automatically runs envsubst on /etc/nginx/templates/

COPY nginx.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]