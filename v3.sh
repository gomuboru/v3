#!/bin/bash

#检测root账户
[ $(id -u) != "0" ] && { echo "请切换至root账户执行此脚本."; exit 1; }

#全局变量
server_ip=`curl -s https://app.52ll.win/ip/api.php`
separate_lines="####################################################################"

install_lnmp_and_ss_panel(){
	yum -y remove httpd
	yum install -y unzip zip git
	#安装lnmp
	clear;echo "选择lnmp版本: [1]lnmp1.3 [2]lnmp1.4 [3]跳过"
	echo -n "请输入序号:"
	read lnmp_version
	
	#lnmp安装选项
	if [ ${lnmp_version} = '1' ];then
		wget -c https://raw.githubusercontent.com/qinghuas/ss-panel-and-ss-py-mu/master/lnmp1.3.zip && unzip lnmp1.3.zip && cd lnmp1.3 && chmod +x install.sh && ./install.sh lnmp
	elif [ ${lnmp_version} = '2' ];then
		echo "lnmp1.4安装选项:2,自定义数据库密码,Y,5,1"
		echo "安装完成后,会提示[Install lnmp V1.4 completed! enjoy it],这时按一下Ctrl+C即可.回车继续.";read
		wget -c http://soft.vpser.net/lnmp/lnmp1.4.tar.gz && tar zxf lnmp1.4.tar.gz && cd lnmp1.4 && ./install.sh lnmp
	elif [ ${lnmp_version} = '3' ];then
		clear;echo "已跳过安装lnmp."
	else
		echo "选项不在范围内,安装终止.";exit
	fi
	
	#获取数据库密码
	if [ ${lnmp_version} = '1' ];then
		mysql_passwd=root
	else
		echo "数据库密码是:"
		read mysql_passwd
		if [ ${mysql_passwd} = '' ];then
			mysql_passwd=root
			echo "已默认数据库密码是:root"
		fi
		echo "---------------------------"
	fi
	
	#检查数据库密码
	echo "数据库密码错误时,会提示:";echo "ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)";echo "---------------------------"
	echo "数据库密码正确时,会提示:";echo "Welcome to the MySQL monitor...(以下省略...)";echo "此时,请输入 exit 退出mysql";echo "---------------------------"
	echo "脚本即将验证数据库密码的正误,请回车继续...";read
	mysql -uroot -p${mysql_passwd}
	#确认数据库密码
	echo "根据上述提示,您判断数据库密码是正确的么？[y/n]"
	read database_password_is_incorrect
	if [ ${database_password_is_incorrect} = 'y' ];then
		echo "数据库密码正确,请回车继续安装...";read
	else
		echo "数据库密码错误,请您确认正确的数据库密码后重试.";exit 0
	fi
	
	#设定站点名称
	clear;echo "请设置站点名称:"
	read ss_panel_name
	if [ ${ss_panel_name} = '' ];then
		ss_panel_name="SS Panel"
		echo "已默认站点名称是:SS Panel"
	fi
	
	#确认安装
	clear;echo "已完成所需设定,确认安装？[y/n]"
	read confirm_the_installation
	if [ ${confirm_the_installation} = 'n' ];then
		echo "取消安装,脚本中止.";exit 0
	fi
	
	#安装前端
	cd /home/wwwroot/default/
	rm -rf index.html
	git clone https://github.com/mmmwhy/mod.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	#修改参数
	wget -P /home/wwwroot/default/config http://sspanel-1252089354.coshk.myqcloud.com/.config.php
	#站点地址,站点名称,数据库密码
	sed -i "s/this_is_sspanel_name/${ss_panel_name}/g" /home/wwwroot/default/config/.config.php
	sed -i "s/this_is_sspanel_address/${server_ip}/g" /home/wwwroot/default/config/.config.php
	sed -i "s/this_is_the_sspanel_database_password/${mysql_passwd}/g" /home/wwwroot/default/config/.config.php
	#继续
	chattr -i .user.ini
	mv .user.ini public
	chown -R root:root *
	chmod -R 777 *
	chown -R www:www storage
	chattr +i public/.user.ini
	wget -N -P  /usr/local/nginx/conf/ http://sspanel-1252089354.coshk.myqcloud.com/nginx.conf
	service nginx restart
	#更换sspanel.sql文件
	rm -rf /home/wwwroot/default/sql/sspanel.sql
	#wget -P /home/wwwroot/default/sql http://sspanel-1252089354.coshk.myqcloud.com/sspanel.sql
	#wget -P /home/wwwroot/default/sql http://sspanel-1252089354.coshk.myqcloud.com/glzjin_all.sql
	#创建数据库
	mysql -uroot -p${mysql_passwd} -e"create database sspanel;" 
	mysql -uroot -p${mysql_passwd} -e"use sspanel;" 
	mysql -uroot -p${mysql_passwd} sspanel < /home/wwwroot/default/sql/glzjin_all.sql
	#其他设置
	cd /home/wwwroot/default
	php composer.phar install
	php -n xcat initdownload
	#定时任务
	yum -y install vixie-cron crontabs
	rm -rf /var/spool/cron/root
	echo 'SHELL=/bin/bash' >> /var/spool/cron/root
	echo 'PATH=/sbin:/bin:/usr/sbin:/usr/bin' >> /var/spool/cron/root
	echo '*/20 * * * * /usr/sbin/ntpdate pool.ntp.org > /dev/null 2>&1' >> /var/spool/cron/root
	echo '30 22 * * * php /home/wwwroot/default/xcat sendDiaryMail' >> /var/spool/cron/root
	echo '0 0 * * * php /home/wwwroot/default/xcat dailyjob' >> /var/spool/cron/root
	echo '*/1 * * * * php /home/wwwroot/default/xcat checkjob' >> /var/spool/cron/root
	/sbin/service crond restart
	#创建管理员账户
	clear;echo "创建管理员账户,稍后按提示设定管理员邮箱和登录密码即可,回车继续...";read
	cd /home/wwwroot/default;php xcat createAdmin;cd /root
	#完成提示
	clear;echo "####################################
# LNMP 与 SS PANEL V3 已安装完成   # 
# 登录地址：http://${server_ip}    # 
####################################"
}

install_centos_ssr(){
	yum -y update
	yum -y install git
	yum -y install python-setuptools && easy_install pip
	yum -y groupinstall "Development Tools"
	#增加1G的Swap分区
	dd if=/dev/zero of=/var/swap bs=1024 count=1048576
	mkswap /var/swap;chmod 0644 /var/swap;swapon /var/swap
	echo '/var/swap   swap   swap   default 0 0' >> /etc/fstab
	#编译安装libsodium
	wget "http://sspanel-1252089354.coshk.myqcloud.com/libsodium-1.0.13.tar.gz"
	tar xf libsodium-1.0.13.tar.gz && cd libsodium-1.0.13
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	easy_install -i https://pypi.org/simple/ supervisor
	#clone shadowsocks
	cd /root
	git clone -b manyuser https://github.com/glzjin/shadowsocks.git "/root/shadowsocks"
	#install devel
	cd /root/shadowsocks
	yum -y install lsof lrzsz python-devel libffi-devel openssl-devel
	pip install -i https://pypi.org/simple/ -r requirements.txt
	cp apiconfig.py userapiconfig.py
	cp config.json user-config.json
}

install_ubuntu_ssr(){
	apt-get -y update
	apt-get -y install build-essential wget iptables git supervisor lsof python-pip
	#编译安装libsodium
	wget -N —no-check-certificate"http://sspanel-1252089354.coshk.myqcloud.com/libsodium-1.0.13.tar.gz"
	tar xf libsodium-1.0.13.tar.gz && cd libsodium-1.0.13
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	pip install cymysql -i https://pypi.org/simple/
	#clone shadowsocks
	cd /root
	git clone -b manyuser https://github.com/glzjin/shadowsocks.git "/root/shadowsocks"
	cd shadowsocks
	pip install -r requirements.txt -i https://pypi.org/simple/
	chmod +x *.sh
	# 配置程序
	cp apiconfig.py userapiconfig.py
	cp config.json user-config.json
}

install_node(){
	#check os version
	check_sys(){
		if [[ -f /etc/redhat-release ]]; then
			release="centos"
		elif cat /etc/issue | grep -q -E -i "debian"; then
			release="debian"
		elif cat /etc/issue | grep -q -E -i "ubuntu"; then
			release="ubuntu"
		elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
			release="centos"
		elif cat /proc/version | grep -q -E -i "debian"; then
			release="debian"
		elif cat /proc/version | grep -q -E -i "ubuntu"; then
			release="ubuntu"
		elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
			release="centos"
	    fi
		bit=`uname -m`
	}
	install_ssr_for_each(){
		check_sys
		if [[ ${release} = "centos" ]]; then
			install_centos_ssr
		else
			install_ubuntu_ssr
		fi
	}
	# 取消文件数量限制
	sed -i '$a * hard nofile 512000\n* soft nofile 512000' /etc/security/limits.conf
	#帮助信息
	echo "#########################################################################################
【前端地址填写规范】
[1]填写IP，需包含http://，例如：http://123.123.123.123
[2]填写域名，需包含http:// 或 https://，例如：https://ssr.domain.com
注意：前端地址若为域名且为https站点，请确保https配置正确(浏览器访问不提示错误即可)

【mukey填写规范】
若没有修改过前端的/home/wwwroot/default/.config.php文件中的$System_Config['muKey']项
则设置该项时，回车即可。若您修改了该项，请输入您设置的值

【节点ID填写规范】
前端搭建完成后，访问前端地址，使用默认管理员账户登陆，管理面板，节点列表，点击右下角的+号
设置节点信息，需要注意的是，节点地址可填域名或IP，节点IP只能填节点IP，设置完成后点添加
返回节点列表，就能看到你刚刚添加的节点的节点ID
#########################################################################################"
	#获取节点信息
	read -p "前端地址是:" Userdomain
	read -p "节点ID是:" UserNODE_ID
	read -p "MuKey是:" Usermukey
	install_ssr_for_each
	#配置节点信息
	cd /root/shadowsocks
	#备份
	cp /root/shadowsocks/userapiconfig.py /root/shadowsocks/userapiconfig.py.bak
	#修改
	Userdomain=${Userdomain:-"http://${server_ip}"}
	sed -i "s#https://zhaoj.in#${Userdomain}#" /root/shadowsocks/userapiconfig.py
	Usermukey=${Usermukey:-"mupass"}
	sed -i "s#glzjin#${Usermukey}#" /root/shadowsocks/userapiconfig.py
	UserNODE_ID=${UserNODE_ID:-"3"}
	sed -i '2d' /root/shadowsocks/userapiconfig.py
	sed -i "2a\NODE_ID = ${UserNODE_ID}" /root/shadowsocks/userapiconfig.py
	#启用supervisord
	echo_supervisord_conf > /etc/supervisord.conf
	sed -i '$a [program:ssr]\ncommand = python /root/shadowsocks/server.py\nuser = root\nautostart = true\nautorestart = true' /etc/supervisord.conf
	supervisord
	#iptables
	iptables -F
	iptables -X  
	iptables -I INPUT -p tcp -m tcp --dport 104 -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 104 -j ACCEPT
	iptables -I INPUT -p tcp -m tcp --dport 1024: -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 1024: -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
	echo 'iptables-restore /etc/sysconfig/iptables' >> /etc/rc.local
	echo "/usr/bin/supervisord -c /etc/supervisord.conf" >> /etc/rc.local
	#创建快捷重启命令
	rm -rf /usr/bin/srs
	echo "#!/bin/bash" >> /usr/bin/srs
	echo "supervisorctl restart ssr" >> /usr/bin/srs
	chmod 777 /usr/bin/srs
	#最后配置
	#/usr/bin/supervisord -c /etc/supervisord.conf
	supervisorctl restart ssr
	#完成提示
	clear;echo "########################################
# SS NODE 已安装完成                   #
########################################
# 启动SSR：supervisorctl start ssr     #
# 停止SSR：supervisorctl stop ssr      #
# 重启SSR：supervisorctl restart ssr   #
# 或：srs                              #
########################################"

}

feiyang(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/mmmwhy/ss-panel-and-ss-py-mu/master/ss-panel-v3-mod.sh && chmod +x ss-panel-v3-mod.sh && bash ss-panel-v3-mod.sh
}

reboot_system(){
	read -p "需重启服务器使配置生效,现在重启? [y/n]" is_reboot
	if [ ${is_reboot} = 'y' ];then
		reboot
	else
		echo "需重启服务器使配置生效,稍后请务必手动重启服务器.";exit
	fi
}

install_bbr(){
	wget --no-check-certificate https://raw.githubusercontent.com/teddysun/across/master/bbr.sh
	chmod 777 bbr.sh;bash bbr.sh
}

restart_supervisor(){
		#判断/usr/bin/killall文件是否存在
		if [ ! -f /usr/bin/killall ];then
			echo "检查到您未安装,脚本将先进行安装..."
			yum -y update;yum -y install psmisc
                killall supervisord
	        killall supervisord
	        killall supervisord
	        killall supervisord
	        supervisord
		else
			killall supervisord
	        killall supervisord
	        killall supervisord
	        killall supervisord
	        supervisord
		fi
}

install_ssh_port(){
	wget -N —no-check-certificate https://www.moerats.com/usr/down/sshport.sh
	chmod 777 sshport.sh;bash sshport.sh
}

restart_ssh_port(){
	systemctl restart sshd.service
}

install_ssrstatus(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/status.sh && chmod +x status.sh
	chmod 777 status.sh;bash status.sh
}

install_screen(){
	yum install screen
}

use_keep(){
	wget -N —no-check-certificate https://github.com/Super-box/v3/raw/master/keep.sh
	screen -S ss
	bash keep.sh
}

update_git(){   
    wget -P /root/shadowsocks -N --no-check-certificate "https://github.com/Super-box/v3/raw/master/00.patch";chmod +x /root/shadowsocks/00.patch
    wget -P /root/shadowsocks -N --no-check-certificate "https://github.com/Super-box/v3/raw/master/01.patch";chmod +x /root/shadowsocks/01.patch
    cd /root/shadowsocks
    git apply 00.patch
    git apply 01.patch

}

install_pm2(){
	#判断/usr/bin/pm2文件是否存在
	    if [ ! -f /usr/bin/pm2 ];then
            echo "检查到您未安装pm2,脚本将先进行安装..."
	    #安装Node.js环境
    	    yum -y install xz
    	    yum -y install wget
    	    wget -N https://nodejs.org/dist/v9.4.0/node-v9.4.0-linux-x64.tar.xz
    	    tar -xvf node-v9.4.0-linux-x64.tar.xz
    	    #设置权限
    	    chmod 777 /root/node-v9.4.0-linux-x64/bin/node
    	    chmod 777 /root/node-v9.4.0-linux-x64/bin/npm
    	    #创建软连接
    	    ln -s /root/node-v9.4.0-linux-x64/bin/node /usr/bin/node
    	    ln -s /root/node-v9.4.0-linux-x64/bin/npm /usr/bin/npm
    	    #安装PM2
    	    npm install -g pm2 --unsafe-perm
    	    #创建软连接x2
    	    ln -s /root/node-v9.4.0-linux-x64/bin/pm2 /usr/bin/pm2
		else
			echo "已经安装pm2，开始配置pm2"
	    fi
}

use_pm2(){
    pm2 delete all
    pm2 start /root/shadowsocks/server.py --name ssr --max-memory-restart 700M

	rm -rf /usr/bin/srs
		echo "#!/bin/bash" >> /usr/bin/srs
	echo "pm2 restart ssr" >> /usr/bin/srs
	chmod 777 /usr/bin/srs
    #创建pm2日志清理
    rm -rf /var/spool/cron/root
    echo 'SHELL=/bin/bash' >> /var/spool/cron/root
    echo 'PATH=/sbin:/bin:/usr/sbin:/usr/bin' >> /var/spool/cron/root
    echo '* */1 * * * pm2 flush' >> /var/spool/cron/root
    echo '0 3 * * * echo 1 > /proc/sys/vm/drop_caches' >> /var/spool/cron/root
    /sbin/service crond restart
    #创建开机自启动
	pm2 save
	pm2 startup
		#完成提示
	clear;echo "########################################
# SS NODE 已安装完成                   #
########################################
# 启动SSR：pm2 start ssr               #
# 停止SSR：pm2 stop ssr                #
# 重启SSR：pm2 restart ssr             #
# 或：srs                              #
########################################"
}

remove_supervisor(){
		#判断/usr/bin/supervisord文件是否存在
		if [ ! -f /usr/bin/supervisord ];then
			echo "supervisor已经卸载"
		else
			killall supervisord
	        killall supervisord
	        killall supervisord
	        killall supervisord
            yum remove supervisor
            apt remove supervisor
		fi
}

install_supervisor(){
   yum install psmisc
   killall supervisord
   yum -y remove supervisor
   rm -rf /etc/supervisord.conf
   rm -rf /usr/bin/srs
   yum -y install supervisor
  #启用supervisord
  echo_supervisord_conf > /etc/supervisord.conf
  sed -i '$a [program:ssr]\ncommand = python /root/shadowsocks/server.py\nuser = root\nautostart = true\nautorestart = true' /etc/supervisord.conf
  supervisord
  #iptables
  iptables -F
  iptables -X  
  iptables -I INPUT -p tcp -m tcp —dport 104 -j ACCEPT
  iptables -I INPUT -p udp -m udp —dport 104 -j ACCEPT
  iptables -I INPUT -p tcp -m tcp —dport 1024: -j ACCEPT
  iptables -I INPUT -p udp -m udp —dport 1024: -j ACCEPT
  iptables-save >/etc/sysconfig/iptables
  echo 'iptables-restore /etc/sysconfig/iptables' » /etc/rc.local
  echo "/usr/bin/supervisord -c /etc/supervisord.conf" » /etc/rc.local
  #创建快捷重启命令
  echo "#!/bin/bash" » /usr/bin/srs
  echo "supervisorctl restart ssr" » /usr/bin/srs
  chmod 777 /usr/bin/srs
  #最后配置
  #/usr/bin/supervisord -c /etc/supervisord.conf
  srs
  #开机自启
  curl https://raw.githubusercontent.com/Supervisor/initscripts/master/centos-systemd-etcs > supervisord.service
mv supervisord.service /etc/systemd/system
chmod 644 /etc/systemd/system/supervisord.service
systemctl daemon-reload
systemctl start supervisord.service
systemctl enable supervisord
systemctl is-enabled supervisord
}

modify_node_info(){
	#检测
	if [ ! -f /root/shadowsocks/userapiconfig.py ];then
		echo "ssr服务端未安装,不能执行该选项.";exit
	else
		#清屏
		clear
		#输出当前节点配置
		echo "当前节点配置如下:"
		echo "------------------------------------"
		sed -n '3p' /root/shadowsocks/userapiconfig.py
		sed -n '17,18p' /root/shadowsocks/userapiconfig.py
		echo "------------------------------------"
		#获取新节点配置信息
		read -p "新的前端地址是:" Userdomain
		read -p "新的节点ID是:" UserNODE_ID
		read -p "新的MuKey是:" Usermukey
	
			#检查
			if [ ! -f /root/shadowsocks/userapiconfig.py.bak ];then
				wget https://github.com/Super-box/v3/raw/master/userapiconfig.py
			else
			#还原
				rm -rf /root/shadowsocks/userapiconfig.py
				cp /root/shadowsocks/userapiconfig.py.bak /root/shadowsocks/userapiconfig.py
			fi
	
		#修改
		Userdomain=${Userdomain:-"http://${server_ip}"}
		sed -i "s#https://zhaoj.in#${Userdomain}#" /root/shadowsocks/userapiconfig.py
		Usermukey=${Usermukey:-"mupass"}
		sed -i "s#glzjin#${Usermukey}#" /root/shadowsocks/userapiconfig.py
		UserNODE_ID=${UserNODE_ID:-"3"}
		sed -i '2d' /root/shadowsocks/userapiconfig.py
		sed -i "2a\NODE_ID = ${UserNODE_ID}" /root/shadowsocks/userapiconfig.py
	fi
}

repair_ssr_operation(){
	echo "正在尝试修复..."
	/usr/bin/supervisord -c /etc/supervisord.conf
	echo "正在重启ssr服务端..."
	supervisorctl restart ssr
	echo "已完成常规修复,若节点仍未恢复正常,请重新启动服务器,然后执行修复."
	echo "少数情况下您可以通过切换系统镜像,或更换安装源来解决此问题."
	echo "同时您应该确认无法连接的问题不是因为防火墙而引发的."
}

update_the_shell(){

		rm -rf /root/v3.sh v3.sh.*
		wget "https://github.com/Super-box/v3/raw/master/v3.sh"

	#将脚本作为命令放置在/usr/bin目录内,最后执行
	rm -rf /usr/bin/v3;cp /root/v3.sh /usr/bin/v3;chmod 777 /usr/bin/v3
	v3
}

replacement_of_installation_source(){
	echo "请选择更换目标源： [1]网易163 [2]阿里云 [3]自定义 [4]恢复默认源"
	read change_target_source
	
	#备份
	mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
	
	#执行
	if [ ${change_target_source} = '1' ];then
		echo "更换目标源:网易163,请选择操作系统版本： [1]Centos 5 [2]Centos 6 [3]Centos 7"
		read operating_system_version
		if [ ${operating_system_version} = '1' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS5-Base-163.repo;yum clean all;yum makecache
		elif [ ${operating_system_version} = '2' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS6-Base-163.repo;yum clean all;yum makecache
		elif [ ${operating_system_version} = '3' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS7-Base-163.repo;yum clean all;yum makecache
		fi
	elif [ ${change_target_source} = '2' ];then
		echo "更换目标源:阿里云,请选择操作系统版本： [1]Centos 5 [2]Centos 6 [3]Centos 7"
		read operating_system_version
		if [ ${operating_system_version} = '1' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-5.repo;yum clean all;yum makecache
		elif [ ${operating_system_version} = '2' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo;yum clean all;yum makecache
		elif [ ${operating_system_version} = '3' ];then
			wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo;yum clean all;yum makecache
		fi
	elif [ ${change_target_source} = '3' ];then
		echo "更换目标源:自定义,请确定您需使用的自定义的源与您的操作系统相符！";echo "请输入自定义源地址："
		read customize_the_source_address
		wget -O /etc/yum.repos.d/CentOS-Base.repo ${customize_the_source_address};yum clean all;yum makecache
	elif [ ${change_target_source} = '4' ];then
		rm -rf /etc/yum.repos.d/CentOS-Base.repo
		mv /etc/yum.repos.d/CentOS-Base.repo.bak /etc/yum.repos.d/CentOS-Base.repo
		yum clean all;yum makecache
	fi
}

configure_firewall(){
	echo "请选择操作： [1]关闭firewall"
	read firewall_operation
	
	if [ ${firewall_operation} = '1' ];then
		echo "停止firewall..."
		systemctl stop firewalld.service
		echo "禁止firewall开机启动"
		systemctl disable firewalld.service
		echo "查看默认防火墙状态,关闭后显示notrunning,开启后显示running"
		firewall-cmd --state
	else
		echo "选项不在范围,操作中止.";exit 0
	fi
}

check_bbr_installation(){
	echo "查看内核版本,含有4.12即可";uname -r
	echo "------------------------------------------------------------"
	echo "返回：net.ipv4.tcp_available_congestion_control = bbr cubic reno 即可";sysctl net.ipv4.tcp_available_congestion_control
	echo "------------------------------------------------------------"
	echo "返回：net.ipv4.tcp_congestion_control = bbr 即可";sysctl net.ipv4.tcp_congestion_control
	echo "------------------------------------------------------------"
	echo "返回：net.core.default_qdisc = fq 即可";sysctl net.core.default_qdisc
	echo "------------------------------------------------------------"
	echo "返回值有 tcp_bbr 模块即说明bbr已启动";lsmod | grep bbr
}

speedtest(){
	#检查文件ZBench-CN.sh是否存在,若不存在,则下载该文件
	if [ ! -f /root/ZBench-CN.sh ];then
		wget https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh
		chmod 777 ZBench-CN.sh
	fi
	#执行测试
	bash /root/ZBench-CN.sh
}

speed(){
	#检查文件superspeed.sh是否存在,若不存在,则下载该文件
	if [ ! -f /root/superspeed.sh ];then
		wget --no-check-certificate https://raw.githubusercontent.com/wn789/Superspeed/master/superspeed.sh
		chmod 777 superspeed.sh
	fi
	#执行测试
    ./superspeed.sh
}

swap(){
	echo "选项：[1]500M [2]1G [3]删除SWAP"
		read swap
	if [ ${swap} = '1' ];then
		#判断/var/swapfile1文件是否存在
		if [ ! -f /var/swapfile1 ];then
			#增加500Mb的Swap分区
			dd if=/dev/zero of=/var/swapfile1 bs=1024 count=512000
			mkswap /var/swapfile1;chmod 0644 /var/swapfile1;swapon /var/swapfile1
			echo "/var/swapfile1 swap swap defaults 0 0" >> /etc/fstab
			echo "已经成功添加SWAP"
		else
			echo "检查到您已经添加SWAP,无需重复添加"
		fi

	elif [ ${swap} = '2' ];then
		#判断/var/swapfile2文件是否存在
		if [ ! -f /var/swapfile1 ];then
		dd if=/dev/zero of=/var/swapfile1 bs=1024 count=1048576
	        mkswap /var/swapfile1;chmod 0644 /var/swapfile1;swapon /var/swapfile1
	        echo '/var/swapfile1 swap swap default 0 0' >> /etc/fstab
	        echo "已经成功添加SWAP"
		else
			echo "检查到您已经添加SWAP,无需重复添加"
		fi

	elif [ ${swap} = '3' ];then
		#判断/var/swapfile1文件是否存在
		if [ ! -f /var/swapfile1 ];then
 		    echo "检查到您未添加SWAP"
		else
	        swapoff /var/swapfile1
                sed -i "/swapfile1/d" /etc/fstab
                rm -rf /var/swapfile1
		fi
	else
		echo "选项不在范围.";exit 0
	fi
}

install_socks5(){
           wget -N —no-check-certificate https://raw.githubusercontent.com/qinghuas/socks5-install/master/ss5.sh
	   chmod 777 ss5.sh;bash ss5.sh
}

network(){
	    service network restart
}


ddns(){
	    wget -N —no-check-certificate https://github.com/Super-box/v3/raw/master/ddns.sh
	    chmod 777 ddns.sh;bash ddns.sh
}


nali_test(){
	echo "请输入目标IP：";read purpose_ip
	nali-traceroute -q 1 ${purpose_ip}
}

besttrace_test(){
	echo "请输入目标IP：";read purpose_ip
	cd /root/besttrace
	./besttrace -q 1 ${purpose_ip}
}

mtr_test(){
	echo "请输入目标IP：";read purpose_ip
	echo "请输入测试次数："
	read MTR_Number_of_tests
	mtr -c ${MTR_Number_of_tests} --report ${purpose_ip}
}

detect_backhaul_routing(){
	echo "选项：[1]Nali [2]BestTrace [3]MTR"
	read detect_backhaul_routing_version
	if [ ${detect_backhaul_routing_version} = '1' ];then
		#判断/root/nali-ipip/configure文件是否存在
		if [ ! -f /root/nali-ipip/configure ];then
			echo "检查到您未安装,脚本将先进行安装..."
			yum -y update;yum -y install traceroute git gcc make
			git clone https://github.com/dzxx36gyy/nali-ipip.git
			cd nali-ipip
			./configure && make && make install
			clear;nali_test
		else
			nali_test
		fi
	elif [ ${detect_backhaul_routing_version} = '2' ];then
		#判断/root/besttrace/besttrace文件是否存在
		if [ ! -f /root/besttrace/besttrace ];then
			echo "检查到您未安装,脚本将先进行安装..."
			yum update -y
			yum install traceroute -y
			wget -N --no-check-certificate "http://sspanel-1252089354.coshk.myqcloud.com/besttrace.tar.gz"
			tar -xzf besttrace.tar.gz && cd besttrace && chmod +x *
			clear;besttrace_test
		else
			besttrace_test
		fi
	elif [ ${detect_backhaul_routing_version} = '3' ];then
		#判断/usr/sbin/mtr文件是否存在
		if [ ! -f /usr/sbin/mtr ];then
			echo "检查到您未安装,脚本将先进行安装..."
			yum update -y;yum install mtr -y
			clear;mtr_test
		else
			mtr_test
		fi
	else
		echo "选项不在范围.";exit 0
	fi
}

serverspeeder(){
	echo "选项：[1]普通安装 [2]安装OVZ BBR"
	read serverspeeder_option
	if [ ${serverspeeder_option} = '1' ];then
		wget -c "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
	elif [ ${serverspeeder_option} = '2' ];then
		wget https://raw.githubusercontent.com/nanqinlang-tcp/tcp_nanqinlang/master/LKL/bash/tcp_nanqinlang-lkl-centos-1.1.1.sh
        chmod +x tcp_nanqinlang-lkl-centos-1.1.1.sh
        bash tcp_nanqinlang-lkl-centos-1.1.1.sh
	fi
}

safe_dog(){
	#判断/usr/bin/sdui文件是否存在
	if [ ! -f /usr/bin/sdui ];then
		echo "检查到您未安装,脚本将先进行安装..."
		wget -N —no-check-certificate  "http://sspanel-1252089354.coshk.myqcloud.com/safedog_linux64.tar.gz"
		tar xzvf safedog_linux64.tar.gz
		mv safedog_an_linux64_2.8.19005 safedog
		cd safedog;chmod +x *.py
		yum -y install mlocate lsof psmisc net-tools
		./install.py
		echo "安装完成,请您重新执行脚本."
	else
		sdui
	fi
}

uninstall_ali_cloud_shield(){
	echo "请选择：[1]卸载阿里云盾 [2]卸载腾讯云盾";read uninstall_ali_cloud_shield

	if [ ${uninstall_ali_cloud_shield} = '1' ];then
    yum -y install redhat-lsb
       var=`lsb_release -a | grep Gentoo`
    if [ -z "${var}" ]; then 
	   var=`cat /etc/issue | grep Gentoo`
    fi

    if [ -d "/etc/runlevels/default" -a -n "${var}" ]; then
	   LINUX_RELEASE="GENTOO"
    else
	   LINUX_RELEASE="OTHER"
    fi

    stop_aegis(){
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 aegis_update >/dev/null 2>&1
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 AliYunDun >/dev/null 2>&1
	killall -9 AliHids >/dev/null 2>&1
	killall -9 AliYunDunUpdate >/dev/null 2>&1
    printf "%-40s %40s\n" "Stopping aegis" "[  OK  ]"
    }

    remove_aegis(){
    if [ -d /usr/local/aegis ];then
       rm -rf /usr/local/aegis/aegis_client
       rm -rf /usr/local/aegis/aegis_update
	   rm -rf /usr/local/aegis/alihids
    fi
    }

   uninstall_service() {
   
   if [ -f "/etc/init.d/aegis" ]; then
		/etc/init.d/aegis stop  >/dev/null 2>&1
		rm -f /etc/init.d/aegis 
   fi

	if [ $LINUX_RELEASE = "GENTOO" ]; then
		rc-update del aegis default 2>/dev/null
		if [ -f "/etc/runlevels/default/aegis" ]; then
			rm -f "/etc/runlevels/default/aegis" >/dev/null 2>&1;
		fi
    elif [ -f /etc/init.d/aegis ]; then
         /etc/init.d/aegis  uninstall
	    for ((var=2; var<=5; var++)) do
			if [ -d "/etc/rc${var}.d/" ];then
				 rm -f "/etc/rc${var}.d/S80aegis"
		    elif [ -d "/etc/rc.d/rc${var}.d" ];then
				rm -f "/etc/rc.d/rc${var}.d/S80aegis"
			fi
		done
    fi

}

stop_aegis
uninstall_service
remove_aegis

printf "%-40s %40s\n" "Uninstalling aegis"  "[  OK  ]"

var=`lsb_release -a | grep Gentoo`
if [ -z "${var}" ]; then 
	var=`cat /etc/issue | grep Gentoo`
fi

if [ -d "/etc/runlevels/default" -a -n "${var}" ]; then
	LINUX_RELEASE="GENTOO"
else
	LINUX_RELEASE="OTHER"
fi

stop_aegis(){
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 aegis_update >/dev/null 2>&1
	killall -9 aegis_cli >/dev/null 2>&1
    printf "%-40s %40s\n" "Stopping aegis" "[  OK  ]"
}

stop_quartz(){
	killall -9 aegis_quartz >/dev/null 2>&1
        printf "%-40s %40s\n" "Stopping quartz" "[  OK  ]"
}

remove_aegis(){
if [ -d /usr/local/aegis ];then
    rm -rf /usr/local/aegis/aegis_client
    rm -rf /usr/local/aegis/aegis_update
fi
}

remove_quartz(){
if [ -d /usr/local/aegis ];then
	rm -rf /usr/local/aegis/aegis_quartz
fi
}


uninstall_service() {
   
   if [ -f "/etc/init.d/aegis" ]; then
		/etc/init.d/aegis stop  >/dev/null 2>&1
		rm -f /etc/init.d/aegis 
   fi

	if [ $LINUX_RELEASE = "GENTOO" ]; then
		rc-update del aegis default 2>/dev/null
		if [ -f "/etc/runlevels/default/aegis" ]; then
			rm -f "/etc/runlevels/default/aegis" >/dev/null 2>&1;
		fi
    elif [ -f /etc/init.d/aegis ]; then
         /etc/init.d/aegis  uninstall
	    for ((var=2; var<=5; var++)) do
			if [ -d "/etc/rc${var}.d/" ];then
				 rm -f "/etc/rc${var}.d/S80aegis"
		    elif [ -d "/etc/rc.d/rc${var}.d" ];then
				rm -f "/etc/rc.d/rc${var}.d/S80aegis"
			fi
		done
    fi

}
stop_aegis
stop_quartz
uninstall_service
remove_aegis
remove_quartz
printf "%-40s %40s\n" "Uninstalling aegis_quartz"  "[  OK  ]"
pkill aliyun-service
rm -fr /etc/init.d/agentwatch /usr/sbin/aliyun-service
rm -rf /usr/local/aegis*
iptables -I INPUT -s 140.205.201.0/28 -j DROP
iptables -I INPUT -s 140.205.201.16/29 -j DROP
iptables -I INPUT -s 140.205.201.32/28 -j DROP
iptables -I INPUT -s 140.205.225.192/29 -j DROP
iptables -I INPUT -s 140.205.225.200/30 -j DROP
iptables -I INPUT -s 140.205.225.184/29 -j DROP
iptables -I INPUT -s 140.205.225.183/32 -j DROP
iptables -I INPUT -s 140.205.225.206/32 -j DROP
iptables -I INPUT -s 140.205.225.205/32 -j DROP
iptables -I INPUT -s 140.205.225.195/32 -j DROP
iptables -I INPUT -s 140.205.225.204/32 -j DROP
    elif [ ${uninstall_ali_cloud_shield} = '2' ];then
        curl -sSL https://down.oldking.net/Script/uninstal_qcloud.sh | sudo bash
	else
		echo "选项不在范围内,更新中止.";exit 0
	fi
}

install_fail2ban(){
	echo "脚本来自:http://www.vpsps.com/225.html";echo "使用简介:https://linux.cn/article-5067-1.html";echo "感谢上述贡献者."
	echo "选择选项: [1]安装fail2ban [2]卸载fail2ban [3]查看封禁列表 [4]为指定IP解锁";read fail2ban_option
	if [ ${fail2ban_option} = '1' ];then
		wget -N —no-check-certificate"http://sspanel-1252089354.coshk.myqcloud.com/fail2ban.sh";bash fail2ban.sh
	elif [ ${fail2ban_option} = '2' ];then
		wget -N —no-check-certificate"https://raw.githubusercontent.com/FunctionClub/Fail2ban/master/uninstall.sh";bash uninstall.sh
	elif [ ${fail2ban_option} = '3' ];then
		echo ${separate_lines};fail2ban-client ping;echo -e "\033[31m[↑]正常返回值:Server replied: pong\033[0m"
		#iptables --list -n;echo -e "\033[31m#当前iptables禁止规则\033[0m"
		fail2ban-client status;echo -e "\033[31m[↑]当前封禁列表\033[0m"
		fail2ban-client status ssh-iptables;echo -e "\033[31m[↑]当前被封禁的IP列表\033[0m"
		sed -n '12,14p' /etc/fail2ban/jail.local;echo -e "\033[31m[↑]当前fail2ban配置\033[0m"
	elif [ ${fail2ban_option} = '4' ];then
		echo "请输入需要解锁的IP地址:";read need_to_unlock_the_ip_address
		fail2ban-client set ssh-iptables unbanip ${need_to_unlock_the_ip_address}
		echo "已为${need_to_unlock_the_ip_address}解除封禁."
	else
		echo "选项不在范围.";exit 0
	fi
}

install_shell(){
	if [ ! -f /usr/bin/v3 ];then
		cp /root/v3.sh /usr/bin/v3;chmod 777 /usr/bin/v3
	else
		clear;echo "Tips:您可通过命令[v3]快速启动本脚本!"
	fi
}

get_server_ip_info(){
	if [ ! -f /root/.server_ip_info.txt ];then
		curl -s myip.ipip.net > /root/.server_ip_info.txt
	fi
	read server_ip_info < /root/.server_ip_info.txt
}

#安装本脚本,获取服务器IP信息
install_shell
get_server_ip_info

#输出安装选项
echo "####################################################################
# 版本：V.2.3.3 2017-10-15                                         #
####################################################################
# [1] Git更新后端                                                  #
# [2] 安装pm2守护后端SSR                                           #
# [3] 修改ssr节点配置                                              #
# [4] 安装ssr节点（肥羊）                                          #
# [5] 优化supervisor                                               #
# [6] 一键安装socks5                                               #
# [7] 一键添加SWAP                                                 #
# [8] 一键更换SSH端口                                              #
# [9] 强制修复后端SSR                                              #
####################################################################
# [a]修复服务端故障 [b]检测BBR安装状态 [c]卸载各类云盾 [d]安装加速 #
# [e]执行测速脚本 [f]查看回程路由 [g]动态IP解析 [h]SpeedTest       #
# [i]配置防火墙 [j]列出开放端口 [k]更换默认源 [l]重启网卡          #
####################################################################
# [x]刷新脚本 [y]更新脚本 [z]退出脚本                              #
# 此服务器IP信息：${server_ip_info}
####################################################################"

stty erase '^H' && read -p "请选择安装项[1-9]/[a-n]:" num
clear
case "$num" in
	1)
	update_git
	;;
	2)
	remove_supervisor
	install_pm2
	use_pm2;;
	3)
	modify_node_info;;
	4)
	feiyang
	reboot_system;;
	5)
	install_supervisor;;
	6)
	install_socks5;;
	7)
	swap;;
	8)
	install_ssh_port
	restart_ssh_port;;
	9)
	restart_supervisor;;
	a)
	repair_ssr_operation;;
	b)
	check_bbr_installation;;
	c)
	uninstall_ali_cloud_shield;;
	d)
	serverspeeder;;
	e)
	speed;;
	f)
	detect_backhaul_routing;;
	g)
	ddns;;
	h)
	speedtest;;
	i)
	configure_firewall;;
	j)
	yum install-y net-tools;netstat -lnp;;
	k)
	replacement_of_installation_source;;
	l)
	network;;
	x)
	bash v3.sh;;
	y)
	update_the_shell;;
	y2)
	rm -rf /root/v3.sh v3.sh.* /usr/bin/v3;wget "https://file.52ll.win/v3.sh"
	cp /root/v3.sh /usr/bin/v3;chmod 777 /usr/bin/v3;v3;;
	z)
	echo "已退出.";exit 0;;
	*)
	echo "选项不在范围内,安装终止."
	exit
	;;
esac

#继续还是中止
echo ${separate_lines};echo -n "继续(y)还是中止(n)? [y/n]:";read continue_or_stop
if [ ${continue_or_stop} = 'y' ];then
	bash v3.sh
fi

#END 2017-10-15 11:47
