#!/bin/bash
check_ok() {
    if [ $? != 0 ];then
        echo "Error, Check the error log."
        exit 1
    fi
}

myum() {
    if ! rpm -qa|grep -q "^$1";then
        yum install -y $1
        check_ok
    else
        echo $1 already installed.
    fi
}
## install some packges.
for p in gcc glibc-devel mercurial;do
    myum $p
done

install_go() {
echo -e "export GOROOT=/usr/local/go\nexport GOOS=linux\nexport GOARCH=386\nexport GOBIN=\$GOROOT/bin\nexport PATH=\$PATH:\$GOBIN" > /etc/profile.d/go.sh
source /etc/profile.d/go.sh
cd /usr/local/src
[ -f go1.8.3.linux-amd64.tar.gz ]||wget https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz
tar -zxf go1.8.3.linux-amd64.tar.gz
[ -d /usr/local/go ] && mv /usr/local/go /usr/local/go.bak.`date "+%s"`
mv go /usr/local/
#/usr/bin/cp -rf /usr/local/go /root/go1.4
cd /usr/local/go/src
./all.bash

go version
echo -e "\033[36m install sucessful\033[0m"
}

install_go
