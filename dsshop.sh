#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

export LANG=en_US.UTF-8
export LC_ALL=C
export COMPOSER_ALLOW_SUPERUSER=1

nginx=$(netstat -anp | grep ':80')
rediss=$(netstat -anp | grep ':6379')
if [ -z "$rediss" ] || [ -z "$nginx" ];then
	echo -e "\n\033[31mredis/nginx error...Please install manually\033[0m\n"
	exit 1;
fi

for phpv in 80 74 73 72 71
do
	if [ -f "/www/server/php/${phpv}/lib/php/extensions/no-debug-non-zts-20190902/fileinfo.so" ];then
		isphpv=$(echo "${phpv}" | awk '{print NR}' | tail -n1)
		version="${phpv}"
	fi
done

if [ $isphpv -lt 1 ];then
	echo -e "\n\033[31mfileinfo error...Please install manually\033[0m\n"
	echo -e "https://box.kancloud.cn/0e4d558660999f444d39d878dc5321c8_1865x789.png"
	echo -e "\n"
	exit 1;
fi

cp /www/server/php/$version/etc/php.ini /tmp/php.bak
sed -i 's/.*disable_functions\ \=\ .*/disable_functions\ \=\ chroot,chgrp,chown,popen,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,popepassthru,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g' /www/server/php/$version/etc/php.ini

/etc/init.d/php-fpm-${version} reload

if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
	yum install -y sudo expect
elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
	apt-get install -y sudo expect
fi

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

wget -qO /www/server/panel/class/datasdshop.py http://download.hanbot.me/dshop/datasdshop.py -T 10
chmod 600 /www/server/panel/class/datasdshop.py
btpython /www/server/panel/class/datasdshop.py > /tmp/datasdshop.json
dbusername=$(cat /tmp/datasdshop.json | grep -Po "${doapiurl}" | awk -v RS='' '{ print $1 }')
if [ -z "$dbusername" ];then
	echo -e "\n\033[31mdbusername error...Please Manual input\033[0m\n"
	read -ep "USERNAME: " dbusername
fi
dbpassword=$(cat /tmp/datasdshop.json | grep -Po "\'username\'\:\ \'${doapiurl}\'\,\ \'password\'\:\ \'\K[[:alnum:]]+")
if [ -z "$dbpassword" ];then
	echo -e "\n\033[31mdbpassword error...Please Manual input\033[0m\n"
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

wget --no-check-certificate -qO /www/wwwroot/dsshop.tar.gz https://github.com/dspurl/dsshop/archive/refs/tags/v2.2.0.tar.gz -T 10

cd /www/wwwroot/

tar -zxf dsshop.tar.gz
rm -rf /www/wwwroot/dsshop.tar.gz

mv {/www/wwwroot/dsshop-2.2.0/api/*,/www/wwwroot/dsshop-2.2.0/api/.*} /www/wwwroot/${apiurl} 2> /dev/null

chown -R www:www ${apiurl}
chmod -R 755 ${apiurl}
rm -rf /www/wwwroot/${apiurl}/.user.ini
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
php artisan key:generate
php artisan passport:keys
php artisan passport:client --password --name=dsshop --provider=admins > client.txt

keypass=$(cat client.txt | grep 'Client secret' | awk '{print $3}')

sed -i "s/.*PASSPORT_CLIENT_SECRET.*/PASSPORT_CLIENT_SECRET=\"${keypass}\"/g" .env;

/etc/init.d/php-fpm-${version} reload


cd ~

echo -e "\n"
echo -e "=================================================================="
echo -e "\033[32mCongratulations! install Dsshop successfully!\033[0m"
echo -e "=================================================================="
echo -e "apidomain: ${apiurl}"
echo -e "username: admin"
echo -e "password: admin"
echo -e "\033[33mThank: Dsshop\033[0m"
echo -e "\033[33mSupport: https://github.com/AckerPaul\033[0m"
echo -e "=================================================================="
echo -e "\n"


