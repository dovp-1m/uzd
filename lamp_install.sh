sudo apt-get update

sudo apt-get install -y build-essential pkg-config autoconf libtool bison re2c sqlite
sudo apt-get install -y libsqlite3-dev libpcre3-dev libssl-dev zlib1g-dev
sudo apt-get build-dep -y mariadb-server

sudo mkdir /opt/src /opt/nginx /opt/mariadb /opt/php

cd /opt/src
wget https://mariadb.mirror.serveriai.lt//mariadb-11.7.2/source/mariadb-11.7.2.tar.gz
tar -zxf mariadb-11.7.2.tar.gz
cd mariadb-11.7.2
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/mariadb
cmake --build .
cmake --install .

groupadd mysql
useradd -r -g mysql -s /bin/false mysql
mkdir /opt/mariadb/data
chown mysql:mysql /opt/mariadb/data

mkdir -p /etc/my.cnf.d

cat > /etc/my.cnf <<EOF
[mysqld]
datadir = /opt/mariadb/data
socket = /tmp/mysql.sock
user = mysql
EOF
chown mysql:mysql /etc/my.cnf
chmod 644 /etc/my.cnf

/opt/mariadb/scripts/mariadb-upgrade --user=mysql --datadir=/opt/mariadb/data
/opt/mariadb/bin/mariadbd-safe --user=mysql --datadir=/opt/mariadb/data &

echo "CREATE USER 'dbadmin'@'10.1.0.73' IDENTIFIED BY 'Unix2025';" | /opt/mariadb/bin/mariadb -u root
echo "GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'10.1.0.73' WITH GRANT OPTION;" | /opt/mariadb/bin/mariadb -u root
echo "FLUSH PRIVILEGES;" | /opt/mariadb/bin/mariadb -u root

cd /opt/src
wget https://www.php.net/distributions/php-8.4.6.tar.gz
tar -zxf php-8.4.6.tar.gz
cd php-8.4.6
./configure --prefix=/opt/php --enable-fpm --with-pdo-mysql=/opt/mariadb
make
make install

cp /opt/php/etc/php-fpm.conf.default /opt/php/etc/php-fpm.conf
sed -i 's/^;listen = .*/listen = \/run\/php-fpm.sock/' /opt/php/etc/php-fpm.conf
sed -i 's/^user = .*/user = www-data/' /opt/php/etc/php-fpm.conf
sed -i 's/^group = .*/group = www-data/' /opt/php/etc/php-fpm.conf

/opt/php/sbin/php-fpm &

cd /opt/src
wget https://nginx.org/download/nginx-1.28.0.tar.gz
tar -zxf nginx-1.28.0.tar.gz
cd nginx-1.28.0
./configure --prefix=/opt/nginx --with-http_ssl_module
make
make install

sed -i 's/^user .*/user www-data;/' /opt/nginx/conf/nginx.conf
mkdir -p /opt/nginx/conf.d
cat > /opt/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

if ! id -u www-data > /dev/null 2>&1; then
    groupadd www-data
    useradd -r -g www-data -s /bin/false www-data
fi

mkdir -p /var/www/html
chown www-data:www-data /var/www/html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php
chown www-data:www-data /var/www/html/info.php

/opt/php/sbin/php-fpm &
/opt/nginx/sbin/nginx &
