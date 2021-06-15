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
GROUP="$( users )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"
SRC="$( cd -P "$DIR/src" && pwd )"
WEB="$( cd -P "$DIR/web" && pwd )"
TMP="$( cd -P "$DIR/tmp" && pwd )"

#install dependencies
brew upgrade autoconf 

brew install intltool autoconf automake python@3.8 gcc perl pcre \
  curl-openssl libiconv pkg-config openssl@1.1 mysql-client oniguruma \
  pcre2 libxml2 icu4c imagemagick mysql libsodium libzip

#install authbind -- allows a non root user to allow a program to bind to a port under 1025
cd ${OPT}
rm -rf ${OPT}/MacOSX-authbind/
git clone https://github.com/Castaglia/MacOSX-authbind.git
cd ${OPT}/MacOSX-authbind
make
sudo make install
cd ${DIR}

# If curl isn't available to the command line then add it to the PATH
if ! [ -x "$(command -v curl)" ]; then
  echo 'export PATH="/usr/local/opt/curl/bin:$PATH"' >> ~/.bash_profile
  export PATH="/usr/local/opt/curl/bin:${PATH}"
fi

# install supervisor with pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
chmod +x get-pip.py
python3 get-pip.py
rm get-pip.py
pip install supervisor

export PATH=$PATH:/usr/local/mysql/bin

# Compile and Install Openresty
tar -xf ${OPT}/openresty-*.tar.gz -C ${OPT}/

# Fix the escape frontslash feature of lua-cjson
sed -i '' s/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, \"\\\\\\\\\/\","/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,"/ßg ${OPT}/openresty-*/bundle/lua-cjson-2.1.0.7/lua_cjson.c

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
make install

cd ${DIR}

# Compile and Install PHP
tar -xf ${OPT}/php-*.tar.gz -C ${OPT}/
cd ${OPT}/php-*/

env PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig:/usr/local/opt/libxml2/lib/pkgconfig:/usr/local/opt/icu4c/lib/pkgconfig:/usr/local/opt/pcre2/lib/pkgconfig \
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
      --with-zip=/usr/local/opt/libzip \
      --with-sodium=/usr/local/opt/sodium \
      --with-mysqli=/usr/local/bin/mysql_config \
      --with-pdo-mysql=mysqlnd \
      --with-mysql-sock=/tmp/mysql.sock \
      --with-pcre-dir=/usr/local/opt/pcre2 \
      --with-pcre-regex=/usr/local/opt/pcre2 \
      --with-imagick=/usr/local/opt/imagemagick \
      --with-iconv=/usr/local/opt/libiconv
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
rm -rf ${OPT}/MacOSX-*/

# Run the configuration
${BIN}/configure-osx.sh