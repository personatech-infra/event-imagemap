FROM node:11.7-alpine as build
WORKDIR /usr/src/app
COPY package.json /usr/src/app/
COPY package-lock.json /usr/src/app/
RUN npm ci
COPY . /usr/src/app/
RUN npm run build
RUN touch /usr/src/app/build/admin

## NGINX Server
# FROM nginx:alpine
FROM fholzer/nginx-brotli
RUN apk --no-cache add bash
COPY etc/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /usr/src/app/build /usr/share/nginx/html
EXPOSE 80
STOPSIGNAL SIGTERM
