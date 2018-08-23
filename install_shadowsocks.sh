#!/bin/bash
#Description: install shadowsocks
shadowsocks_port=1234
shadowsocks_pwd='20180823'
hostname=hongkong.ss.com

#函数用来初始化系统
env_init(){
    hostnamectl set-hostname "$hostname"
    yum install -y epel-release
    yum update -y   #注意，非新机器请注释该句
    更改 ssh远程端口
    grep '^Port' /etc/ssh/sshd_config \
    && sed -i '/^Port/s/Port.*/Port 9988/g' /etc/ssh/sshd_config || sed -i '/^#Port/a\Port 9988' /etc/ssh/sshd_config
    systemctl restart sshd.service
}

#函数用来安装ss
install_shadowsocks(){
    yum install -y python-setuptools m2crypto supervisor
    easy_install pip
    pip install shadowsocks

    cat  > /etc/shadowsocks.json <<EOF
{
    "server":"0.0.0.0",
    "server_port":"$shadowsocks_port",
    "local_port":1080,
    "password":"$shadowsocks_pwd",
    "timeout":600,
    "method":"aes-256-cfb"
}
EOF

    cat  > /etc/init.d/shadowsocks <<EOF
#!/bin/bash
# Author:
# chkconfig: - 90 10
# description: Shadowsocks start/stop/status/restart script

Shadowsocks_bin=/usr/bin/ssserver
Shadowsocks_conf=/etc/shadowsocks.json

#Shadowsocks_USAGE is the message if this script is called without any options
Shadowsocks_USAGE="Usage: \$0 {\e[00;32mstart\e[00m|\e[00;31mstop\e[00m|\e[00;32mstatus\e[00m|\e[00;31mrestart\e[00m}"

#SHUTDOWN_WAIT is wait time in seconds for shadowsocks proccess to stop
SHUTDOWN_WAIT=20

Shadowsocks_pid(){
	echo \`ps -ef | grep \$Shadowsocks_bin | grep -v grep | tr -s " "|cut -d" " -f2\`
}

start() {
  pid=\$(Shadowsocks_pid)
  if [ -n "\$pid" ];then
    echo -e "\e[00;31mShadowsocks is already running (pid: \$pid)\e[00m"
  else
    \$Shadowsocks_bin -c \$Shadowsocks_conf -d start
    RETVAL=\$?
    if [ "\$RETVAL" = "0" ]; then
    	echo -e "\e[00;32mStarting Shadowsocks\e[00m"
    else
    	echo -e "\e[00;32mShadowsocks start Failed\e[00m"
    fi
    status
  fi
  return 0
}

status(){
  pid=\$(Shadowsocks_pid)
  if [ -n "\$pid" ];then
    echo -e "\e[00;32mShadowsocks is running with pid: \$pid\e[00m"
  else
    echo -e "\e[00;31mShadowsocks is not running\e[00m"
  fi
}

stop(){
  pid=\$(Shadowsocks_pid)
  if [ -n "\$pid" ];then
    echo -e "\e[00;31mStoping Shadowsocks\e[00m"
    \$Shadowsocks_bin -c \$Shadowsocks_conf -d stop
    let kwait=\$SHUTDOWN_WAIT
    count=0;
    until [ \`ps -p \$pid | grep -c \$pid\` = '0' ] || [ \$count -gt \$kwait ]
    do
      echo -n -e "\e[00;31mwaiting for processes to exit\e[00m\n";
      sleep 1
      let count=\$count+1;
    done

    if [ \$count -gt \$kwait ];then
      echo -n -e "\n\e[00;31mkilling processes which didn't stop after \$SHUTDOWN_WAIT seconds\e[00m"
      kill -9 \$pid
    fi
  else
    echo -e "\e[00;31mShadowsocks is not running\e[00m"
  fi

  return 0
}

case \$1 in
	start)
          start
        ;;
        stop)
          stop
        ;;
        restart)
          stop
          start
        ;;
        status)
	  status
        ;;
        *)
	  echo -e \$Shadowsocks_USAGE
        ;;
esac
exit 0
EOF

    chmod 755 /etc/init.d/shadowsocks && chkconfig --add shadowsocks && chkconfig  shadowsocks --level 2345 on
    service shadowsocks start
}

main(){
    # env_init
    install_shadowsocks
}

main > /tmp/"$0".log 2>&1