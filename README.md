
# BTDSShop install
	wget --no-check-certificate -qO /tmp/dsshop.sh https://raw.githubusercontent.com/AckerPaul/btdsshop/main/dsshop.sh && chmod +x /tmp/dsshop.sh && sh /tmp/dsshop.sh

安装前请确保已经安装nginx,php>7,mysql,redis,fileinfo

脚本会自动判断这些必要组件没有就会自动退出

目前默认仅支持自动部署api端

APP_URL就是api的url地址,直接回车代表使用IP为域名;

默认自动获取宝塔创建网站时生成的数据库名和密码

数据库名一致就可以,密码是动态获取的,后面看情况支持选择指定数据库

如果不一致会提示你输入数据库名和密码的

自动清理laravel php必备函数

自动配置nginx伪静态

自动配置运行目录

# 待实现的功能
一键部署web

一键部署admin

一键部署h5
