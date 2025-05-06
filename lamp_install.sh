sudo apt-get update
sudo apt-get install -y wget build-essential libssl-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libfreetype6-dev libmcrypt-dev libreadline-dev unzip

mkdir -p /opt/src /opt/nginx /opt/mariadb /opt/php

cd /opt/src
wget https://nginx.org/download/nginx-1.26.3.tar.gz
tar -zxvf nginx-1.26.3.tar.gz
cd nginx-1.26.3
./configure --prefix=/opt/nginx
make
sudo make install

/opt/nginx/sbin/nginx

