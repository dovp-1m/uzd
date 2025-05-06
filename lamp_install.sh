sudo apt-get update
sudo apt-get install -y curl make git tar cmake wget build-essential unzip

mkdir -p /opt/src /opt/nginx /opt/mariadb /opt/php

cd /opt/src
wget https://nginx.org/download/nginx-1.26.3.tar.gz
tar -zxvf nginx-1.26.3.tar.gz
cd nginx-1.26.3
./configure --prefix=/opt/nginx -with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module --with-threads --with-stream --with-stream_ssl_module --with-mail --with-mail_ssl_module
make
sudo make install

/opt/nginx/sbin/nginx

cd /opt/src
wget https://mariadb.mirror.serveriai.lt//mariadb-11.7.2/source/mariadb-11.7.2.tar.gz
tar -zxvf mariadb-11.7.2.tar.gz
cd mariadb-11.7.2
cmake . -DCMAKE_INSTALL_PREFIX=/opt/mariadb -DMYSQL_DATADIR=/opt/mariadb/data -DINSTALL_SYSCONFDIR=/etc/mysql -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_unicode_ci
make
sudo make install

sudo mkdir -p /opt/mariadb/data
sudo chown -R mysql:mysql /opt/mariadb/data
sudo /opt/mariadb/scripts/mysql_install_db --user=mysql --basedir=/opt/mariadb --datadir=/opt/mariadb/data

sudo /opt/mariadb/bin/mysql_secure_installation <<EOF
n
Unix2025
Unix2025
y
y
y
y
EOF

sudo /opt/mariadb/bin/mysql -u root -pUnix2025 -e "CREATE USER 'dbadmin'@'10.1.0.73' IDENTIFIED BY 'Unix2025'; GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'10.1.0.73' WITH GRANT OPTION; FLUSH PRIVILEGES;"

cd /opt/src
wget https://www.php.net/distributions/php-8.4.6.tar.gz
tar -zxvf php-8.4.6.tar.gz
cd php-8.4.6
./configure --prefix=/opt/php --with-config-file-path=/opt/php/etc --with-fpm-user=www-data --with-fpm-group=www-data --enable-fpm --with-mysqli --with-pdo-mysql --with-iconv --with-zlib --with-curl --with-jpeg-dir --with-png-dir --with-freetype-dir --with-readline --with-libxml-dir --with-xsl --with-gd --with-mhash --with-openssl --enable-mbstring --enable-intl --enable-opcache
make
sudo make install

cp php.ini-production /opt/php/etc/php.ini
cp /opt/php/etc/php-fpm.conf.default /opt/php/etc/php-fpm.conf
cp /opt/php/etc/php-fpm.d/www.conf.default /opt/php/etc/php-fpm.d/www.conf

sudo /opt/php/sbin/php-fpm --nodaemonize

sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

curl http://localhost/info.php


