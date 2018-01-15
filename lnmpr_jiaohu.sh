#!/bin/bash
#Author: Aaron
#Date: 2016-04-29
#description: 该脚本适用于Centos系统

###### defined variable ######
cp_name=XXX        #公司名称缩写

#php进程运行用户,密码
php_user=www
#php_user_ps=123456

#Nginx安装相关变量
nginx_user=www
#nginx_user_ps=123456
www_vhost=xxx          #官网虚拟主机配置文件名前缀
DOMAIN="www.xxx.com"   #nginx官网虚拟主机对应的域名
web_dir=/data/wwwroot/xxx
SSL_PEM=        #SSL证书路径
SSL_KEY=

#redis密码
redis_user=redis
redis_ps=123456
mem_size=256mb
######  defined variable end  #######

echo -e "\033[31m################################################################
##                                                            ##
##          \033[36mIt will install lnmp(Author：刘明) \033[31m                 ##
##                                                            ##
################################################################\033[0m"
sleep 1 
##check last command is OK or not.
check_ok()
{
    if [ $? != 0 ]
    then
        echo "Error, Check the error log."
        exit 1
    fi
}

##get the archive of the system,i686 or x86_64.
ar=`arch`

##close seliux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
selinux_s=`getenforce`
if [ $selinux_s == "Enforcing"  -o $selinux_s == "enforcing" ]
then
    setenforce 0
fi

##close firewall
systemctl stop firewalld.service
systemctl disable firewalld.service

##if the packge installed ,then omit.
myum()
{
    if ! rpm -qa|grep -q "^$1"
    then
        yum install -y $1
        check_ok
    else
        echo $1 already installed.
    fi
}

## install some packges.
for p in wget automake autoconf libtool gcc gcc-c++ zlib-devel libaio-devel
do
    myum $p
done

##install epel.
if rpm -qa epel-release >/dev/null
then
    rpm -e epel-release
fi
if ls /etc/yum.repos.d/epel-7.repo* >/dev/null 2>&1
then
    rm -f /etc/yum.repos.d/epel-7.repo*
fi
wget -P /etc/yum.repos.d/ http://mirrors.aliyun.com/repo/epel-7.repo

##function of intsall mysql.
install_mysql()
{
    echo -e "\033[36mChose the version of mysql.\033[0m\n"
    select mysql_v in 5.1 5.6
    do
        if ! grep '^mysql:' /etc/passwd
        then
            useradd -M mysql -s /sbin/nologin
        fi
        mkdir -pv /data/mysql
        myum compat-libstdc++-33
        case $mysql_v in
          5.1)
            cd /usr/local/src
            [ -f mysql-5.1.73-linux-$ar-glibc23.tar.gz ] || wget  http://mirrors.sohu.com/mysql/MySQL-5.1/mysql-5.1.73-linux-x86_64-glibc23.tar.gz
            tar zxf  mysql-5.1.73-linux-x86_64-glibc23.tar.gz
            check_ok
            /bin/mv mysql-5.1.73-linux-x86_64-glibc23   /usr/local/mysql
            check_ok
            [ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_`date +%s`
            mkdir -p /data/mysql
            chown -R mysql:mysql /data/mysql
            cd /usr/local/mysql
            ./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
            check_ok
            /bin/cp support-files/my-large.cnf /etc/my.cnf
            check_ok
            sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
            /bin/cp support-files/mysql.server /etc/init.d/mysqld
            sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
            chmod 755 /etc/init.d/mysqld
            chkconfig --add mysqld
            chkconfig mysqld on
            service mysqld start
            check_ok
            break
            ;;
          5.6)
            cd /usr/local/src
            [ -f mysql-5.6.36-linux-glibc2.5-$ar.tar.gz ] || wget https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.36-linux-glibc2.5-x86_64.tar.gz
            tar zxf  mysql-5.6.36-linux-glibc2.5-x86_64.tar.gz
            check_ok
            [ -d /usr/local/mysql ] && /bin/mv /usr/local/mysql /usr/local/mysql_bak
            mv mysql-5.6.36-linux-glibc2.5-x86_64   /usr/local/mysql
            [ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_bak
            mkdir -p /data/mysql
            chown -R mysql:mysql /data/mysql
            cd /usr/local/mysql
            ./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
            check_ok
            /bin/cp support-files/my-default.cnf /etc/my.cnf
            check_ok
            sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
            /bin/cp support-files/mysql.server /etc/init.d/mysqld
            sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
            chmod 755 /etc/init.d/mysqld
             /etc/init.d/mysqld start
            chkconfig --add mysqld
            chkconfig mysqld on
            service mysqld start
             check_ok
            break
            ;;
          *)
            echo "only 1(5.1) or 2(5.6)"
            ;;
        esac
    done
    yum remove mysql -y
    echo "export export PATH=\$PATH:/usr/local/mysql/bin" >> /etc/profile.d/path.sh
    source /etc/profile.d/path.sh
}

##function of install nginx.
install_nginx()
{
    myum pcre-devel zlib-devel openssl-devel
    if ! grep -q "^$nginx_user:" /etc/passwd
	then
        useradd  -M -s /sbin/nologin $nginx_user
    fi
    mkdir -pv $web_dir
    cd /usr/local/src
    [ -f nginx-1.10.3.tar.gz ] || wget http://nginx.org/download/nginx-1.10.3.tar.gz
    tar -zxvf nginx-1.10.3.tar.gz
    check_ok
    cd nginx-1.10.3
    ##隐藏nginx版本信息
    sed -i 's/\#define NGINX_VERSION      "1.10.3"/\#define NGINX_VERSION      "7.0"/' ./src/core/nginx.h
    sed -i "s/\#define NGINX_VER          \"nginx\/\"/#define NGINX_VER          \"$cp_name\/\"/" ./src/core/nginx.h
    sed -i "s/\#define NGINX_VAR          \"NGINX\"/\#define NGINX_VAR          \"$cp_name\"/" ./src/core/nginx.h
    sed -i "/ngx_http_server_string\[\] =/s/nginx/$cp_name/" src/http/ngx_http_header_filter_module.c
    sed -i "/full_string\[\]/s/Server\: /Server\: $cp_name/" src/http/ngx_http_header_filter_module.c
    sed -i "/NGINX_VER/s/<\//\(http\:\/\/$DOMAIN\)<\//" src/http/ngx_http_special_response.c
    sed -i "/<hr><center>nginx/s/<hr><center>nginx/<hr><center>$cp_name/" src/http/ngx_http_special_response.c
    ./configure --prefix=/usr/local/nginx --user=$nginx_user --group=$nginx_user --with-http_stub_status_module --with-http_ssl_module --with-pcre
    check_ok
    make && make install
    check_ok
    if [ -f /etc/init.d/nginx ]
    then
        /bin/mv /etc/init.d/nginx  /etc/init.d/nginx_`date +%s`
    fi
    curl http://www.apelearn.com/study_v2/.nginx_init  -o /etc/init.d/nginx
    check_ok
    chmod 755 /etc/init.d/nginx
    chkconfig --add nginx
    chkconfig nginx on
    ##nginx主配置文件
    cat > /usr/local/nginx/conf/nginx.conf << EOF
user $nginx_user $nginx_user;
worker_processes 2;
error_log /usr/local/nginx/logs/nginx_error.log crit;
pid /usr/local/nginx/logs/nginx.pid;
worker_rlimit_nofile 51200;

events
{
    use epoll;
    worker_connections 6000;
}

http
{
    include mime.types;
    default_type application/octet-stream;
    server_names_hash_bucket_size 3526;
    server_names_hash_max_size 4096;
    log_format $cp_name '\$remote_addr \$http_x_forwarded_for [\$time_local]'
    '\$host "\$request_uri" \$status'
    '"\$http_referer" "\$http_user_agent"';
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 30;
    client_header_timeout 3m;
    client_body_timeout 3m;
    send_timeout 3m;
    connection_pool_size 256;
    client_header_buffer_size 1k;
    large_client_header_buffers 8 4k;
    request_pool_size 4k;
    output_buffers 4 32k;
    postpone_output 1460;
    client_max_body_size 50m;
    client_body_buffer_size 256k;
    client_body_temp_path /usr/local/nginx/client_body_temp;
    proxy_temp_path /usr/local/nginx/proxy_temp;
    fastcgi_temp_path /usr/local/nginx/fastcgi_temp;
    fastcgi_intercept_errors on;
    tcp_nodelay on;
    gzip on;
    gzip_min_length 1k;
    gzip_buffers 4 8k;
    gzip_comp_level 5;
    gzip_http_version 1.1;
    gzip_types text/plain application/x-javascript text/css text/htm application/xml;
    server_tokens off;
    include vhosts/*.conf;
#    include /data/block.ip;
}
EOF
    check_ok
    [ -d /usr/local/nginx/conf/vhosts ] || mkdir -v /usr/local/nginx/conf/vhosts
    ##nginx默认虚拟主机配置
    cat > /usr/local/nginx/conf/vhosts/default.conf << EOF
server
{
    listen 80 default_server;
    server_name localhost;
    index index.html index.htm index.php;
    root /tmp/1233;
    deny all;

}
EOF
    ##官网虚拟主机配置
    cat > /usr/local/nginx/conf/vhosts/"$www_vhost".conf << EOF
server {
    listen 80;
    #listen 443 ssl;
    #ssl_certificate   $SSL_PEM;
    #ssl_certificate_key  $SSL_KEY;
    #ssl_session_timeout 5m;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    #ssl_prefer_server_ciphers on;

    server_name  $DOMAIN;
    root $web_dir;
    index index.html index.htm index.php;

    if (\$http_user_agent ~ 'bingbot/2.0|MJ12bot/v1.4.2|Spider/3.0|YoudaoBot|Tomato|Gecko/20100315') {
        return 403;
    }
    access_log /tmp/access.log $cp_name;

    location / {
        if (!-e \$request_filename) {
        rewrite  ^(.*)$  /index.php?s=\$1  last;
        break;
        }
    }

    location ~ .*.(php|php5)?$ {
        fastcgi_pass unix:/dev/shm/php-fcgi.sock;
        fastcgi_index index.php;
        include fastcgi.conf;
        #include  fastcgi_params;
        #fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    #error_page   500 502 503 504  /50x.html;
    #error_page   400 403 404  /40x.html; #错误优雅显示
    #location = /50x.html {
    #root   /www/50x.html;
    #}

    }
EOF
    service nginx start
    check_ok
	echo "export PATH=$PATH:/usr/local/nginx/sbin" >> /etc/profile.d/path.sh
    source /etc/profile
}

##function of install php-fpm
install_phpfpm()
{
    echo -e "Install php.\nPlease chose the version of php."
    select php_v in 5.4 5.6
    do
        case $php_v in
            5.4)
                cd /usr/local/src/
                [ -f php-5.4.45.tar.bz2 ] || wget 'http://cn2.php.net/get/php-5.4.45.tar.bz2/from/this/mirror' -O php-5.4.45.tar.bz2
                tar jxf php-5.4.45.tar.bz2 && cd php-5.4.45
                for p in  openssl-devel bzip2-devel \
                libxml2-devel curl-devel libpng-devel \
                libjpeg-devel freetype-devel libmcrypt-devel\
                libtool-ltdl-devel perl-devel
                do
                    myum $p
                done
                if ! grep -q "^$php_user:" /etc/passwd
                then
                    useradd  -M -s /sbin/nologin $php_user
                fi
                ./configure \
                --prefix=/usr/local/php-fpm \
                --with-config-file-path=/usr/local/php-fpm/etc \
                --enable-fpm \
                --with-fpm-user=php-fpm \
                --with-fpm-group=php-fpm \
                --with-mysql=mysqlnd \
                --with-pdo-mysql=mysqlnd \
                --with-mysqli \
                --with-libxml-dir \
                --with-gd \
                --with-jpeg-dir \
                --with-png-dir \
                --with-freetype-dir \
                --with-iconv-dir \
                --with-zlib-dir \
                --with-mcrypt \
                --enable-sockets \
                --enable-soap \
                --enable-gd-native-ttf \
                --enable-ftp \
                --enable-mbstring \
                --enable-exif \
                --enable-zend-multibyte \
                --disable-ipv6 \
                --with-pear \
                --with-curl \
                --with-openssl
                check_ok
                make && make install
                check_ok
                [ -f /usr/local/php-fpm/etc/php.ini ] || /bin/cp php.ini-production  /usr/local/php-fpm/etc/php.ini
                if /usr/local/php-fpm/bin/php -i |grep -iq 'date.timezone => no value'
                then
                    sed -i '/;date.timezone =$/a\date.timezone = "Asia\/Chongqing"'  /usr/local/php-fpm/etc/php.ini
                    check_ok
                fi
                [ -f /usr/local/php-fpm/etc/php-fpm.conf ] || curl http://www.apelearn.com/study_v2/.phpfpm_conf -o /usr/local/php-fpm/etc/php-fpm.conf
    #            sed -i "s/listen =.*/listen = 127.0.0.1:9000/g" /usr/local/php-fpm/etc/php-fpm.conf
                sed -i "s/listen =.*/listen = \/dev\/shm\/php-fcgi.sock/g" /usr/local/php-fpm/etc/php-fpm.conf
                sed -i 's/user =.*/user = www/g;s/group =.*/group = www/g'  /usr/local/php-fpm/etc/php-fpm.conf
                [ -f /etc/init.d/phpfpm ] || /bin/cp sapi/fpm/init.d.php-fpm /etc/init.d/phpfpm
                chmod 755 /etc/init.d/phpfpm
                chkconfig phpfpm on
                service phpfpm start
                check_ok
                break
                ;;
            5.6)
                cd /usr/local/src/
                [ -f php-5.6.30.tar.gz ] || wget -O php-5.6.30.tar.gz http://cn2.php.net/get/php-5.6.30.tar.gz/from/this/mirror
                tar zxf php-5.6.30.tar.gz &&   cd php-5.6.30
                for p in  openssl-devel bzip2-devel \
                libxml2-devel curl-devel libpng-devel \
                libjpeg-devel freetype-devel libmcrypt-devel\
                libtool-ltdl-devel perl-devel
                do
                    myum $p
                done
    
                if ! grep -q "^$php_user:" /etc/passwd
                then
                    useradd  -M -s /sbin/nologin $php_user
                fi
                check_ok
                ./configure \
                --prefix=/usr/local/php-fpm \
                --with-config-file-path=/usr/local/php-fpm/etc \
                --with-fpm-user=$php_user \
                --with-fpm-group=$php_user \
                --with-mysql \
                --with-pdo-mysql \
                --with-mysqli \
                --with-libxml-dir \
                --with-gd \
                --with-jpeg-dir \
                --with-png-dir \
                --with-freetype-dir \
                --with-iconv-dir \
                --with-zlib-dir \
                --with-mcrypt \
                --enable-sockets \
                --enable-fpm \
                --enable-soap \
                --enable-gd-native-ttf \
                --enable-ftp \
                --enable-mbstring \
                --enable-exif \
                --disable-ipv6 \
                --with-pear \
                --with-curl \
                --with-openssl
                check_ok
                make && make install
                check_ok
                [ -f /usr/local/php-fpm/etc/php.ini ] || /bin/cp php.ini-production  /usr/local/php-fpm/etc/php.ini
                if /usr/local/php-fpm/bin/php -i |grep -iq 'date.timezone => no value'
                then
                    sed -i '/;date.timezone =$/a\date.timezone = "Asia\/Chongqing"'  /usr/local/php-fpm/etc/php.ini
                    check_ok
                fi
                [ -f /usr/local/php-fpm/etc/php-fpm.conf ] || curl http://www.apelearn.com/study_v2/.phpfpm_conf -o /usr/local/php-fpm/etc/php-fpm.conf
                sed -i "s/listen =.*/listen = \/dev\/shm\/php-fcgi.sock/g" /usr/local/php-fpm/etc/php-fpm.conf
                sed -i 's/user =.*/user = www/g;s/group =.*/group = www/g'  /usr/local/php-fpm/etc/php-fpm.conf
                check_ok
                [ -f /etc/init.d/phpfpm ] || /bin/cp sapi/fpm/init.d.php-fpm /etc/init.d/phpfpm
                chmod 755 /etc/init.d/phpfpm
                #/etc/init.d/phpfpm start
                chkconfig phpfpm on
                service phpfpm start
    #            check_ok
                break
                ;;
    
            *)
                echo 'only 1(5.4) or 2(5.6)'
                ;;
        esac
    done
}

##function of intsall redis.
install_redis()
{
    echo -e "\033[36mStart installing redis...\033[0m"
    ##创建redis用户
    if ! grep '^$redis_user:' /etc/passwd
    then
        useradd  -s /sbin/nologin $redis_user
    fi
    #下载redis，编译安装
    cd  /usr/local/src
    [ -f redis-3.2.8.tar.gz ] || wget http://download.redis.io/releases/redis-3.2.8.tar.gz
    tar zxf redis-3.2.8.tar.gz
    check_ok
    [ -d /usr/local/redis ] && mv /usr/local/redis /usr/local/redis_`date +%s`
    cd  redis-3.2.8
    make
    check_ok
    make install  PREFIX=/usr/local/redis
    check_ok
    mkdir /usr/local/redis/etc/
    ##redis主配置
    cat > /usr/local/redis/etc/redis.conf << EOF
daemonize yes
pidfile /usr/local/redis/var/redis.pid
port 6379
timeout 300
loglevel debug
logfile /usr/local/redis/var/redis.log
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename dump.rdb
dir /usr/local/redis/var/
appendonly no
appendfsync always
maxmemory $mem_size
maxmemory-policy allkeys-lru
requirepass $redis_ps
EOF
    ##redis启动脚本
    [ -f /etc/init.d/redis ] && mv /etc/init.d/redis /etc/init.d/redis_`date +%s`
    cat > /etc/init.d/redis << EOF
#!/bin/sh
#
# redis        init file for starting up the redis daemon
#
# chkconfig:   - 20 80
# description: Starts and stops the redis daemon.

# Source function library.
. /etc/rc.d/init.d/functions

name="redis-server"
REDIS_USER="$redis_user"
basedir="/usr/local/redis"
exec="\$basedir/bin/\$name"
pidfile="\$basedir/var/redis.pid"
REDIS_CONFIG="\$basedir/etc/redis.conf"

[ -e /etc/sysconfig/redis ] && . /etc/sysconfig/redis

lockfile=/var/lock/subsys/redis

start() {
    [ -f \$REDIS_CONFIG ] || exit 6
    [ -x \$exec ] || exit 5
    echo -n \$"Starting \$name: "
    daemon --user \${REDIS_USER:-redis} "\$exec \$REDIS_CONFIG"
    retval=\$?
    echo
    [ \$retval -eq 0 ] && touch \$lockfile
    return \$retval
}

stop() {
    echo -n \$"Stopping \$name: "
    killproc -p \$pidfile \$name
    retval=\$?
    echo
    [ \$retval -eq 0 ] && rm -f \$lockfile
    return \$retval
}

restart() {
    stop
    start
}

reload() {
    false
}

rh_status() {
    status -p \$pidfile \$name
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}


case "\$1" in
    start)
        rh_status_q && exit 0
        \$1
        ;;
    stop)
        rh_status_q || exit 0
        \$1
        ;;
    restart)
        \$1
        ;;
    reload)
        rh_status_q || exit 7
        \$1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo \$"Usage: \$0 {start|stop|status|restart|condrestart|try-restart}"
        exit 2
esac
exit \$?
EOF

    mkdir /usr/local/redis/var/
    chmod 777 /usr/local/redis/var/
    chmod 755 /etc/init.d/redis
    if ! chkconfig --list |grep 'redis' ;then chkconfig --add redis && chkconfig redis  on;fi
    #/etc/init.d/redis start
    service redis start
    #check_ok
    echo "export export PATH=\$PATH:/usr/local/redis/bin" >> /etc/profile.d/path.sh
	source /etc/profile
}

##The function of install php extension module
install_php_extension()
{
    mod_name=$1
    /usr/local/php-fpm/bin/phpize > cache.log
    #DIR=`echo $(cat cache.log |awk -F ':' '/Zend Module/ {print $2}')`
    ./configure --with-php-config=/usr/local/php-fpm/bin/php-config
    check_ok
    make && make install
    check_ok
    if ! grep "^extension_dir" /usr/local/php/etc/php.ini
	then
	    sed -i '/^\[PHP\]$/a\extension_dir = $mod_name' /usr/local/php/etc/php.ini
	else
        sed -i "/^extension\_dir/a\extension = $mod_name" /usr/local/php-fpm/etc/php.ini
    fi
	unset mod_name
}

##function of install redis extension module
install_php_redismod()
{
    cd /usr/local/src
    [ -f redis-3.1.1.tgz ]||wget http://pecl.php.net/get/redis-3.1.1.tgz
    ./check_ok.sh
    tar -zxf redis-3.1.1.tgz
    ./check_ok.sh
    cd redis-3.1.1
    install_php_extension redis.so
}


echo -e "\033[36mPlease select the software package you need to install\n\n
    1  [install lnmp]\n\n    
	2  [install lnmpr]\n\n
	3  [install nginx]\n\n
	4  [install mysql]\n\n
	5  [install redis]\n\n
	6  [install php(redis_mod)]\n\n
	7  [exit]\n\033[0m"
read -p "Please chose which type env you install, [lnmp]:  " t
${t:=1}

case $t in
  1)
    install_mysql
    install_nginx
    install_phpfpm
    echo -e "\033[36mAll install complete. \033[0m"
    ;;
  2)
    install_mysql
    install_nginx
    install_phpfpm
    install_redis
    install_php_redismod
    echo -e "\033[36mlnmpr install complete. \033[0m"
    ;;
  3)
    install_nginx
    echo -e "\033[36mnginx install complete. \033[0m"
    ;;
  4)
    install_mysql
    echo -e "\033[36mmysql install complete. \033[0m"
    ;;
  5)
    install_redis
    echo -e "\033[36mredis install complete. \033[0m"
    ;;
  6)
    install_phpfpm
    install_php_redismodule
    echo -e "\033[36mlnmpr install complete. \033[0m"
    ;;
  7)
    exit 0
	;;
  *)
    echo -e "\033[31mError\nPlease follow the prompts to enter one of 1 to 7 ！！\033[0m"
    ;;
esac