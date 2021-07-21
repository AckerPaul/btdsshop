#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

export LANG=en_US.UTF-8
export LC_ALL=C
export COMPOSER_ALLOW_SUPERUSER=1

if [ $(whoami) != "root" ];then
	echo "Please use root permission to execute"
	exit 1;
fi

if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
	yum install -y wget curl sudo expect
	centosv=$(cat /etc/redhat-release | grep -Po 'release\ \K[0-9]\.[0-9]' | awk '{ sub(/\./,""); print $0 }')
elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
	apt-get install -y wget curl sudo expect
fi

if [ $centosv -le 76 ];then
	echo -e "\n\033[31mOutdated Centos Version...Please install manually\033[0m\n"
	echo -e "\n"
	exit 1;
fi

if [ ! -f "/www/server/panel/license.txt" ];then
	echo -e "\n\033[31m检测到您未安装宝塔,5秒后将自动安装宝塔nginx1.20 mysql5.7 php7.4时间较长,耐心等候\033[0m\n"
	echo -e "\n\033[31mNot installed BTPanel,pagoda nginx1.20 mysql5.7 php7.4 will be installed automatically in 5 seconds\033[0m\n"
	sleep 5
	wget -qO /tmp/install_panel.sh http://download.bt.cn/install/install_panel.sh -T 10
	tac /tmp/install_panel.sh > /tmp/install_panelc.sh
	sed -i '2,13d' /tmp/install_panelc.sh
	sed -i '/\/www\/server\/panel\/data\/bind\.pl/d' /tmp/install_panelc.sh
	tac /tmp/install_panelc.sh > /tmp/install_panel.sh
	rm -f /tmp/install_panelc.sh
	chmod +x /tmp/install_panel.sh
	echo 'y' | bash /tmp/install_panel.sh
	sleep 3
	/etc/init.d/bt default > /tmp/defaultps.txt
	sleep 3
	rm -f /tmp/install_panel.sh
	mkdir -p /www/server/nginx/html
	mkdir -p /www/server/nginx/conf
	mkdir -p /www/server/nginx/logs
	mkdir -p /www/server/nginx/sbin
	wget -qO /tmp/lib.sh http://download.bt.cn/install/0/lib.sh -T 10
	chmod +x /tmp/lib.sh
	bash /tmp/lib.sh
	sleep 1
	rm -f /tmp/lib.sh
fi

if [ ! -f "/www/server/panel/data/licenes.pl" ];then
	echo -n 'True' > /www/server/panel/data/licenes.pl
fi
if [ -f "/www/server/panel/data/bind.pl" ];then
	rm -f /www/server/panel/data/bind.pl
fi

nginx=$(netstat -anp | grep 'nginx')
if [ -z "$nginx" ] && [ ! -f "/www/server/nginx/sbin/nginx" ];then
	wget -qO /tmp/nginx.sh http://download.bt.cn/install/0/nginx.sh  -T 10
	chmod +x /tmp/nginx.sh
	bash /tmp/nginx.sh install 1.20
	sleep 1
	rm -f /tmp/nginx.sh
fi
sleep 1
nginx -v
sleep 1
nginx=$(netstat -anp | grep 'nginx')
if [ -z "$nginx" ];then
	/etc/init.d/nginx start 2> /dev/null > nginx.txt
	sleep 1
	nginxstart=$(cat nginx.txt | grep 'running')
	if [ -z "$nginxstart" ];then
		nginx -v
		echo -e "\n\033[31mnginx...Installation failed\033[0m\n"
		echo -e "\n"
		exit 1;
	fi
fi

if [ ! -d "/www/server/mysql/bin" ];then
	wget -qO /tmp/mysql.sh http://download.bt.cn/install/0/mysql.sh  -T 10
	chmod +x /tmp/mysql.sh
	bash /tmp/mysql.sh install 5.7
	sleep 1
	rm -f /tmp/mysql.sh
fi

phpvs=$(php -v 2> /dev/null)
if [ -z "$phpvs" ];then
	wget -qO /tmp/php.sh http://download.bt.cn/install/0/php.sh  -T 10
	chmod +x /tmp/php.sh
	bash /tmp/php.sh install 74
	sleep 1
	rm -f /tmp/php.sh
fi

phpvs=$(php -v 2> /dev/null)
if [ ! -f "/www/server/nginx/sbin/nginx" ] || [ -z "$phpvs" ];then
	echo -e "\n\033[31mnginx/php...Installation failed\033[0m\n"
	echo -e "\n"
	exit 1;
fi

rediss=$(netstat -anp | grep ':6379')
phpv=$(ls /www/server/php 2> /dev/null | awk -v RS='' '{ print $1 }')
if [ -z "$phpv" ];then
	echo -e "\n\033[31mphp...Installation failed\033[0m\n"
	echo -e "\n"
	exit 1;
fi
if [ -z "$rediss" ] && [ ! -d "/www/server/redis" ];then
	wget -qO /tmp/redis.sh http://download.bt.cn/install/0/redis.sh  -T 10
	chmod +x /tmp/redis.sh
	bash /tmp/redis.sh install ${phpv}
	sleep 1
	rm -f /tmp/redis.sh
fi
isfileinfo=$(cat /www/server/php/${phpv}/etc/php.ini|grep 'fileinfo.so')
if [ -z "$isfileinfo" ];then
	wget -qO /tmp/fileinfo.sh http://download.bt.cn/install/0/fileinfo.sh  -T 10
	chmod +x /tmp/fileinfo.sh
	bash /tmp/fileinfo.sh install ${phpv}
	sleep 1
	rm -f /tmp/fileinfo.sh
fi

cp /www/server/php/${phpv}/etc/php.ini /tmp/php.bak
sed -i 's/.*disable_functions\ \=\ .*/disable_functions\ \=\ chroot,chgrp,chown,popen,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,popepassthru,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g' /www/server/php/${phpv}/etc/php.ini

/etc/init.d/php-fpm-${phpv} reload

read -ep "APP_URL: (Enter represents the IP as the domain name)" apiurl

ipapiurl=$(echo -n "${apiurl}" | grep -Eo "[0-9.]+")

if [ -z "$apiurl" ] || [ "$ipapiurl" != "" ];then
	wget -qO /tmp/get_geo2ip.json http://www.bt.cn/api/panel/get_geo2ip -T 10
	geoip=$(cat /tmp/get_geo2ip.json | grep -Po '\"ip_address\"\:\"\K[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+')
	apiurl="${geoip}"
	doapiurl=$(echo -n "${geoip}" | awk '{ gsub(/\./,"_"); print $0 }')
else
	apiurl=$(echo -n "${apiurl}" | grep -Eo "[a-zA-Z0-9.]+\.[a-zA-Z]{2,3}")
	doapiurl=$(echo -n "${apiurl}" | awk '{ gsub(/\./,"_"); print $0 }')
fi

wget -qO /tmp/ds.tar.gz http://download.hanbot.me/dshop/ds.tar.gz -T 10
cd /tmp
tar -zxf ds.tar.gz
rm -rf ds.tar.gz
mv -f /tmp/ds/restapiv.py /www/server/panel/class/restapiv.py
mv -f /tmp/ds/btapis.py /www/server/panel/class/btapis.py
mv -f /tmp/ds/datasdshop.py /www/server/panel/class/datasdshop.py
chmod 600 /www/server/panel/class/restapiv.py
chmod 600 /www/server/panel/class/btapis.py
chmod 600 /www/server/panel/class/datasdshop.py

if [ -f "/www/server/panel/config/api.json" ];then
	rm -f /www/server/panel/config/api.json
fi
btpython /www/server/panel/class/restapiv.py
sleep 1
btpython /www/server/panel/class/btapis.py sites > /tmp/sites.json
sitesname=$(cat /tmp/sites.json | grep -Po "${apiurl}" | awk -v RS='' '{ print $1 }')
if [ -z "$sitesname" ];then
	export APISURL="${apiurl}"
	export APIPHPV="${phpv}"
	btpython /www/server/panel/class/btapis.py createweb
fi
if [ ! -f "/www/server/panel/data/not_workorder.pl" ];then
	btpython /www/server/panel/class/btapis.py workorder
fi
if [ -f "/www/wwwroot/${apiurl}/.user.ini" ];then
	rm -rf /www/wwwroot/${apiurl}/index.html
	btpython /www/server/panel/class/btapis.py userini
fi

btpython /www/server/panel/class/datasdshop.py > /tmp/datasdshop.json
dbusername=$(cat /tmp/datasdshop.json | grep -Po "${doapiurl}" | awk -v RS='' '{ print $1 }')
if [ -z "$dbusername" ];then
	echo -e "\n\033[31mdbusername error...Please input manually after creation\033[0m\n"
	echo -e "\n"
	read -ep "USERNAME: " dbusername
fi
dbpassword=$(cat /tmp/datasdshop.json | grep -Po "\'username\'\:\ \'${doapiurl}\'\,\ \'password\'\:\ \'\K[[:alnum:]]+")
if [ -z "$dbpassword" ];then
	echo -e "\n\033[31mdbpassword error...Please Manual input\033[0m\n"
	echo -e "\n"
	read -ep "PASSWORD: " dbpassword
fi

if [ ! -f "/usr/bin/composer" ];then
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/bin/composer
fi

cat > /tmp/dsshop.conf <<\EOF
location / {  
	try_files $uri $uri/ /index.php$is_args$query_string;  
}  
EOF

if [ -f "/www/server/panel/vhost/rewrite/${apiurl}.conf" ];then
	rewrites=$(cat "/www/server/panel/vhost/rewrite/${apiurl}.conf" | grep 'try_files')
	if [ -z "$rewrites" ];then
		mv -f /tmp/dsshop.conf /www/server/panel/vhost/rewrite/${apiurl}.conf
	fi
else
	mv -f /tmp/dsshop.conf /www/server/panel/vhost/rewrite/${apiurl}.conf
fi

wget -qO /tmp/dsversion.txt http://download.hanbot.me/dshop/dsversion.txt -T 10
geocode=$(cat /tmp/get_geo2ip.json | grep -Po '\"iso_code\"\:\"\K[[:alpha:]]+' | awk -v RS='' '{ print $1 }')

if [[ "$geocode" != 'CN' ]]; then
	wget --no-check-certificate -qO /tmp/dsversion.json https://api.github.com/repos/dspurl/dsshop/releases/latest -T 10
	dsversion=$(cat /tmp/dsversion.json | grep -Po '\"tag_name\"\:\ \"\K[[:alnum:].]+' | awk -v RS='' '{ print $1 }')
	wget --no-check-certificate -qO /www/wwwroot/dsshop.tar.gz https://github.com/dspurl/dsshop/archive/refs/tags/${dsversion}.tar.gz -T 10
else
	dsversion=$(cat /tmp/dsversion.txt)
	wget -O /www/wwwroot/dsshop.tar.gz http://download.hanbot.me/dshop/${dsversion}.tar.gz -T 10
fi

cd /www/wwwroot/

tar -zxf dsshop.tar.gz
rm -rf /www/wwwroot/dsshop.tar.gz
dsversions=$(cat /tmp/dsversion.txt | grep -Eo "[0-9.]+")
mv -f /tmp/ds/dsshop-demo.sql /www/wwwroot/dsshop-${dsversions}/api/storage/app/dsshop-demo.sql
mv {/www/wwwroot/dsshop-${dsversions}/api/*,/www/wwwroot/dsshop-${dsversions}/api/.*} /www/wwwroot/${apiurl} 2> /dev/null

chown -R www:www ${apiurl}
chmod -R 755 ${apiurl}
cd /www/wwwroot/${apiurl}

composer install

mv .env.dev .env

sed -i "s/APP_URL=http\:\/\/localhost/APP_URL=http\:\/\/${apiurl}/g" .env;
sed -i "s/.*DB_DATABASE.*/DB_DATABASE=${dbusername}/g" .env;
sed -i "s/.*DB_USERNAME.*/DB_USERNAME=${dbusername}/g" .env;
sed -i "s/.*DB_PASSWORD.*/DB_PASSWORD=${dbpassword}/g" .env;
sed -i 's/.*REDIS_PASSWORD.*/REDIS_PASSWORD=/g' .env;
sed -i "s/.*PASSPORT_CLIENT_ID.*/PASSPORT_CLIENT_ID=\'1\'/g" .env;
sed -i "s/.*root\ \/www\/wwwroot\/.*/root\ \/www\/wwwroot\/${apiurl}\/public\;/g" /www/server/panel/vhost/nginx/${apiurl}.conf;

if [ -f "/usr/bin/nginx" ];then
	/usr/bin/nginx -s reload
else
	nginx -s reload
fi

php artisan migrate -n
php artisan generate:demo
php artisan storage:link
sleep 1
php artisan key:generate
sleep 1
php artisan passport:keys
sleep 1
php artisan passport:client --password --name=dsshop --provider=admins > client.txt
sleep 1
keypass=$(cat client.txt | grep 'Client secret' | awk '{print $3}')

sed -i "s/.*PASSPORT_CLIENT_SECRET.*/PASSPORT_CLIENT_SECRET=\"${keypass}\"/g" .env;

/etc/init.d/php-fpm-${phpv} reload

while [ "$goadmin" != 'y' ] && [ "$goadmin" != 'n' ]
do
	read -p "Whether to deploy Admin (y/n): " goadmin;
done

if [ "$goadmin" = 'y' ]; then
	if [ ! -f "/www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3/config/prod.env.js" ];then
		echo -e "\n\033[31mUnsupported version...Contact me to fix\033[0m\n"
		echo -e "\n"
		exit 1;
	fi
	if [ ! -f "/www/server/panel/plugin/pm2/info.json" ];then
		wget -qO /tmp/pm2.sh http://download.bt.cn/install/0/pm2.sh  -T 10
		chmod +x /tmp/pm2.sh
		bash /tmp/pm2.sh install
		sleep 1
	fi
	nodev=$(ls /www/server/nvm/versions/node | awk -v RS='' '{ print $1 }')
	ln -s /www/server/nvm/versions/node/${nodev}/bin/node /usr/local/bin/node
	ln -s /www/server/nvm/versions/node/${nodev}/bin/npm /usr/local/bin/npm
	wget -qO adminv3.zip http://download.hanbot.me/dshop/adminv3.zip  -T 10
	unzip -o adminv3.zip -d /www/wwwroot/${apiurl}/public/ > /dev/null
	rm -f adminv3.zip
	cd /www/wwwroot/${apiurl}/public/adminv3/static/js
	sed -i "s/vkcloud\.me/${apiurl}/g" app.9d658aaf.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-096b.5add0012.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-2660.bb162b52.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-27df.2a44cf8b.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-31cd.d69aa370.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-36ed.7bc22fec.js
	sleep 1
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-513f.fcdd270f.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-56f6.844a7c2f.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-641e.c532d37b.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-8ffc.2a50b628.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-b440.42b40749.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-dd37.49741e53.js
	sed -i "s/vkcloud\.me/${apiurl}/g" chunk-e4cb.b5577bb1.js
	cd ..
	sleep 1
	while [ "$gobuild" != 'y' ] && [ "$gobuild" != 'n' ]
	do
		read -p "New npm run build,not suggested/不懂的请选n (y/n): " gobuild;
	done
	if [ "$gobuild" = 'y' ]; then
		cd /www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3
		sed -i "s/dsshop\.test/${apiurl}/g" /www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3/config/dev.env.js
		sed -i "s/dsshop\.test/${apiurl}/g" /www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3/config/prod.env.js
		sed -i "s/admin/adminv3/g" /www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3/config/index.js
		npm install
		sleep 3
		npm run build:prod
		sleep 3
		rm -rf /www/wwwroot/${apiurl}/public/adminv3
		mv /www/wwwroot/dsshop-${dsversions}/admin/vue2/element-admin-v3/dist /www/wwwroot/${apiurl}/public/adminv3
	fi
	chown -R www:www /www/wwwroot/${apiurl}/public/adminv3
	chmod -R 755 /www/wwwroot/${apiurl}/public/adminv3
fi

cd ~

while [ "$goweb" != 'y' ] && [ "$goweb" != 'n' ]
do
	read -p "Whether to deploy Web (y/n): " goweb;
done
if [ "$goweb" = 'y' ] && [ "$goadmin" = 'y' ]; then
	cd /www/wwwroot/dsshop-${dsversions}/client/nuxt-web/mi
	wget -qO /tmp/nuxt.config.js http://download.hanbot.me/dshop/nuxt.config.js  -T 10
	\cp -f /tmp/nuxt.config.js nuxt.config.js
	mv .env.prod .env
	sed -i "s/dsshop\.test/${apiurl}/g" .env
	npm install
	sleep 3
	npm i sass-loader node-sass sass-resources-loader -D
	sleep 3
	npm i ufo --save
	npm run generate 2> /dev/null
	mv dist /www/wwwroot/${apiurl}/public/web
	mv /www/wwwroot/${apiurl}/public/web/200.html /www/wwwroot/${apiurl}/public/web/index.html
	chown -R www:www /www/wwwroot/${apiurl}/public/web
	chmod -R 755 /www/wwwroot/${apiurl}/public/web
fi

cd ~
rm -rf /tmp/ds
rm -f /tmp/pm2.sh
rm -f /tmp/get_geo2ip.json
rm -f /www/server/panel/class/restapiv.py
rm -f /www/server/panel/class/btapis.py
rm -f /www/server/panel/class/datasdshop.py
rm -f /tmp/dsversion.txt
rm -f /tmp/dsversion.json
rm -f /tmp/dsshop.conf
rm -f /tmp/sites.json
rm -f /tmp/nuxt.config.js
rm -f /tmp/datasdshop.json

echo -e "\n"
echo -e "=================================================================="
echo -e "\033[32mCongratulations! install Dsshop successfully!\033[0m"
echo -e "=================================================================="
echo -e "apiurl: http://${apiurl}"
if [ "$goadmin" = 'y' ]; then
	echo -e "adminurl: http://${apiurl}/adminv3"
fi
if [ "$goweb" = 'y' ]; then
	echo -e "weburl: http://${apiurl}/web/"
fi
echo -e "username: admin"
echo -e "password: AckerPaul"
echo -e "\033[33mThank: Dsshop\033[0m"
echo -e "\033[33mSupport: https://github.com/AckerPaul/btdsshop\033[0m"
echo -e "\033[33mSupport: vkcloud.me\033[0m"
echo -e "\033[33mTelegram: https://t.me/vkcloudme\033[0m"
echo -e "=================================================================="
echo -e "\n"

if [ -f "/tmp/defaultps.txt" ];then
	echo -e "\n"
	sed -i '2 a https\:\/\/github.com\/AckerPaul\/btdsshop' /tmp/defaultps.txt
	cat /tmp/defaultps.txt
	rm -f /tmp/defaultps.txt
fi

rm -f /tmp/cloud_deployment.sh

