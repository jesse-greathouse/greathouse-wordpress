#!/usr/bin/env bash

#   +---------------------------------------------------------------------------------+
#   | This file is part of greathouse-wordpress                                       |
#   +---------------------------------------------------------------------------------+
#   | Copyright (c) 2017 Greathouse Technology LLC (http://www.greathouse.technology) |
#   +---------------------------------------------------------------------------------+
#   | greathouse-wordpress is free software: you can redistribute it and/or modify    |
#   | it under the terms of the GNU General Public License as published by            |
#   | the Free Software Foundation, either version 3 of the License, or               |
#   | (at your option) any later version.                                             |
#   |                                                                                 |
#   | greathouse-wordpress is distributed in the hope that it will be useful,         |
#   | but WITHOUT ANY WARRANTY; without even the implied warranty of                  |
#   | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                   |
#   | GNU General Public License for more details.                                    |
#   |                                                                                 |
#   | You should have received a copy of the GNU General Public License               |
#   | along with greathouse-wordpress.  If not, see <http://www.gnu.org/licenses/>.   |
#   +---------------------------------------------------------------------------------+
#   | Author: Jesse Greathouse <jesse@greathouse.technology>                          |
#   +---------------------------------------------------------------------------------+

# resolve real path to script including symlinks or other hijinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET="$(readlink "$SOURCE")"
  if [[ ${TARGET} == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE="$TARGET"
  else
    BIN="$( dirname "$SOURCE" )"
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$BIN')"
    SOURCE="$BIN/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
USER="$( whoami )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"
SRC="$( cd -P "$DIR/src" && pwd )"
WEB="$( cd -P "$DIR/web" && pwd )"

# install dependencies
sudo yum -y update && sudo yum -y install \
  centos-release-scl intltool autoconf automake python3 python3-pip gcc perl pcre \
  git-core curl libcurl-devel pkgconfig openssl openssl-devel mariadb-client mariadb-devel \
  pcre2 libxml2 libicu ImageMagick-devel ImageMagick libzip ncurses-devel

# install oniguruma
curl -o ${OPT}/oniguruma-6.8.2-1.el7.x86_64.rpm https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/o/oniguruma-6.8.2-1.el7.x86_64.rpm
rpm ${OPT}/oniguruma-6.8.2-1.el7.x86_64.rpm
yum -y install oniguruma
rm ${OPT}/oniguruma-6.8.2-1.el7.x86_64.rpm

# install Sodium
curl -o ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/libsodium-1.0.18-1.el7.x86_64.rpm
rpm ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm
yum -y install libsodium
rm ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm

scl enable python3 bash
pip install supervisor

# Compile and Install Openresty
tar -xzf ${OPT}/openresty-*.tar.gz -C ${OPT}/

# Fix the escape frontslash feature of cjson
sed -i -e s/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, \"\\\\\\\\\/\","/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,"/g ${OPT}/openresty-*/bundle/lua-cjson-2.1.0.7/lua_cjson.c

cd ${OPT}/openresty-*/
./configure --with-cc-opt="-I/usr/local/include -I/usr/local/opt/openssl/include" \
            --with-ld-opt="-L/usr/local/lib -L/usr/local/opt/openssl/lib" \
            --prefix=${OPT}/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-http_iconv_module \
            --with-http_realip_module \
            --with-http_ssl_module \
            -j2 && \
make
make install

cd ${DIR}

# Compile and Install PHP
tar -xf ${OPT}/php-*.tar.gz -C ${OPT}/
cd ${OPT}/php-*/

./configure \
  --prefix=${OPT}/php \
  --sysconfdir=${ETC} \
  --with-config-file-path=${ETC}/php \
  --with-config-file-scan-dir=${ETC}/php/conf.d \
  --enable-opcache \
  --enable-fpm \
  --enable-dom \
  --enable-exif \
  --enable-fileinfo \
  --enable-hash \
  --enable-imagick \
  --enable-json \
  --enable-mbstring \
  --enable-bcmath \
  --enable-intl \
  --enable-ftp \
  --enable-mysqli \
  --without-sqlite3 \
  --without-pdo-sqlite \
  --with-ssh2 \
  --with-mcrypt \
  --with-libxml \
  --with-simplexml \
  --with-xmlreader \
  --with-xsl \
  --with-xmlrpc \
  --with-zlib \
  --with-curl \
  --with-webp \
  --with-openssl \
  --with-zip \
  --with-sodium \
  --with-mysqli \
  --with-pdo-mysql \
  --with-mysql-sock \
  --with-pcre-dir \
  --with-pcre-regex \
  --with-imagick \
  --with-iconv
make
make install

cd ${DIR}

# Download and Install Wordpress
curl -o ${OPT}/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xf ${OPT}/wordpress.tar.gz -C ${OPT}/ --exclude="wp-content"
cp -r ${OPT}/wordpress/* ${WEB}/

# Cleanup
rm ${OPT}/wordpress.tar.gz
rm -rf ${OPT}/wordpress
rm -rf ${OPT}/openresty-*/
rm -rf ${OPT}/php-*/

${BIN}/configure-centos.sh