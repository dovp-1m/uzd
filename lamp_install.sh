sudo apt-get update
sudo apt-get install -y build-essential pkg-config autoconf libtool bison re2c cmake \
    libsqlite3-dev libpcre3-dev libssl-dev zlib1g-dev libxml2-dev libcurl4-openssl-dev \
    libjpeg-dev libpng-dev libwebp-dev libfreetype6-dev libonig-dev wget curl

# Create necessary directories
sudo mkdir -p /opt/src /opt/nginx /opt/mariadb /opt/php

cd /opt/src
wget https://mariadb.mirror.serveriai.lt/mariadb-11.7.2/source/mariadb-11.7.2.tar.gz
tar -zxf mariadb-11.7.2.tar.gz
cd mariadb-11.7.2
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/mariadb
cmake --build .
cmake --install .


sudo groupadd -f mysql
sudo useradd -r -g mysql -s /bin/false mysql || true

sudo mkdir -p /opt/mariadb/data
sudo chown -R mysql:mysql /opt/mariadb

cat > /etc/my.cnf.d <<EOF
[mysqld]
datadir = /opt/mariadb/data
socket = /tmp/mysql.sock
user = mysql
bind-address = 0.0.0.0
EOF

sudo chown mysql:mysql /etc/my.cnf
sudo chmod 644 /etc/my.cnf

sudo /opt/mariadb/scripts/mysql_install_db --basedir=/opt/mariadb --datadir=/opt/mariadb/data --user=mysql
sudo /opt/mariadb/bin/mariadbd-safe --defaults-file=/etc/my.cnf &

/opt/mariadb/bin/mariadb -u root <<SQL
CREATE USER 'dbadmin'@'10.1.0.73' IDENTIFIED BY 'Unix2025';
GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'10.1.0.73' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

cd /opt/src
wget https://www.php.net/distributions/php-8.4.6.tar.gz
tar -zxf php-8.4.6.tar.gz
cd php-8.4.6

./configure --prefix=/opt/php --enable-fpm --with-mysqli=/opt/mariadb/bin/mysql_config \
    --with-pdo-mysql=/opt/mariadb --with-openssl --with-zlib --with-curl
make -j$(nproc)
make install

cp /opt/php/etc/php-fpm.conf.default /opt/php/etc/php-fpm.conf
sed -i 's@;listen =.*@listen = /opt/php/run/php-fpm.sock@' /opt/php/etc/php-fpm.conf
sed -i 's@^user =.*@user = www-data@' /opt/php/etc/php-fpm.conf
sed -i 's@^group =.*@group = www-data@' /opt/php/etc/php-fpm.conf

mkdir -p /opt/php/run
/opt/php/sbin/php-fpm &

cd /opt/src
wget https://nginx.org/download/nginx-1.28.0.tar.gz
tar -xf nginx-1.28.0.tar.gz
cd nginx-1.28.0

./configure --prefix=/opt/nginx --with-http_ssl_module
make -j$(nproc)
make install

if ! id -u www-data &>/dev/null; then
    sudo groupadd www-data
    sudo useradd -r -g www-data -s /bin/false www-data
fi

mkdir -p /opt/nginx/conf.d
cat <<EOF > /opt/nginx/conf/nginx.conf
user www-data;
worker_processes auto;
error_log logs/error.log;
pid logs/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    include /opt/nginx/conf.d/*.conf;
}
EOF

cat <<EOF > /opt/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/opt/php/run/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

mkdir -p /var/www/html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php
chown -R www-data:www-data /var/www/html

/opt/nginx/sbin/nginx

echo "Testing http://localhost/info.php ..."
curl -s http://localhost/info.php | grep -q "phpinfo()" && echo "PHP is working!" || echo "PHP test failed!"

