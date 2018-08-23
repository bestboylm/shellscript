#!/bin/bash

cd /usr/local/src
[ -f node-v8.11.3-linux-x64.tar.xz ] || wget https://nodejs.org/dist/v8.11.3/node-v8.11.3-linux-x64.tar.xz
tar -Jxvf node-v8.11.3-linux-x64.tar.xz
mv node-v8.11.3-linux-x64 /usr/local/node
echo "PATH=\$PATH:/usr/local/node/bin" >> /etc /profile.d/path.sh