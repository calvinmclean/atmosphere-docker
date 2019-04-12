FROM nginx:latest

RUN apt-get update && apt-get install -y openssl

RUN openssl dhparam -out /etc/ssl/certs/dhparam.pem 1024

ADD ./default.conf /etc/nginx/conf.d/default.conf
