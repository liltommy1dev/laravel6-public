###
### Laravel 6 install template
###

if [ $# != 2 ]; then
	echo 引数エラー: $*
	exit 1
else
	echo OK
fi

# 引数の取得
MysqlDBName=$1
MysqlRootPasswd=$2


##
## PHP と php-fpm を Amazon Linux にインストールする
##

# PHP 7.3 をインストールする
# 同時に php-fpm もインストールされる
sudo amazon-linux-extras install php7.3 -y

# yumのアップデートをしておく
sudo yum update -y
sudo yum upgrade -y

# PHP Laravel に必要なモジュールをインストールする
sudo yum install php-devel php-opcache php-mbstring php-xml php-mcrypt pyp-mysqlnd -y

# php-fpm を起動する
sudo systemctl start php-fpm.service

# サーバー起動時に php-fpm を自動で起動する
# 必要があればこのコマンドを叩く
sudo systemctl enable php-fpm.service

##
## nginx を Amaxon Linux にインストールする
## 

# nginx をインストールする
sudo amazon-linux-extras install nginx1.12 -y

# nginxを起動する
sudo systemctl start nginx.service

# サーバー起動時にnginxを自動的に起動する
# 必要があればこのコマンドを叩く
sudo systemctl enable nginx.service

##
## nginx の設定
##
sudo cp -p /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org 
sudo cp ./nginx.conf.template /etc/nginx/nginx.conf

##
## php-fpm の設定
##

sudo cp ./nignx.laravel.conf.template /etc/nginx/conf.d/laravel.conf

##
## MySQLのインストール・設定
##

#mysql8.0リポジトリの追加（このリポジトリに5.7も含まれています）
sudo yum localinstall https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm -y

#mysql8.0リポジトリの無効化
sudo yum-config-manager --disable mysql80-community

#mysql5.7リポジトリの有効化
sudo yum-config-manager --enable mysql57-community

#mysqlインストール
sudo yum install mysql-community-server -y

#自動起動設定
sudo systemctl start mysqld.service
sudo systemctl enable mysqld.service
sudo systemctl status mysqld.service


sudo yum install expect -y

# 初期パスワードを取得
Int_Passwd=$(sudo grep "A temporary password is generated for root@localhost:" /var/log/mysqld.log \
| awk '{ print $11}')
 
# パスワード自動作成
# MysqlRootPasswd="$(mkpasswd -l 16 | tee -a ~/.mysql.secrets)"

expect -c '
    set timeout 10;
    spawn mysql_secure_installation;
    expect "Enter password for user root:";
    send "'"${Int_Passwd}"'\n";
    expect "New password:";
    send "'"${MysqlRootPasswd}"'\n";
    expect "Re-enter new password:";
    send "'"${MysqlRootPasswd}"'\n";
    expect "Change the password for root ?";
    send "n\n";
    expect "Remove anonymous users?";
    send "y\n";
    expect "Disallow root login remotely?";
    send "y\n";
    expect "Remove test database and access to it?";
    send "y\n";
    expect "Reload privilege tables now?";
    send "y\n";
    interact;'

# 文字コードの変更
sudo cp -p /etc/my.cnf /etc/my.cnf.org
sudo cp ./my.cnf.template /etc/my.cnf


#mysql再起動
sudo systemctl restart mysqld.service

# MySQLにlaravel DB作成 
expect -c '
    set timeout 10;
    spawn mysql -u root -p;
    expect "Enter password:";
    send "'"${MysqlRootPasswd}"'\n";
    expect "mysql>";
    send "create database laravel;\n";
    expect "mysql>";
    send "exit\n";
    interact;'


##
## laravel 設定
##

# composerのインストール

sudo curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

sudo mkdir /home/laravel
sudo chown -R ec2-user:ec2-user /home/laravel
sudo chmod -R 755 /home/laravel


cd /home/laravel
composer create-project "laravel/laravel=6.*" laravel-app
cd /home/laravel/laravel-app
cp -p .env.example .env
php artisan key:generate

# .envにDB名を設定
sed -i -e "s/DB_DATABASE=laravel/DB_DATABASE=${MysqlDBName}/g" .env
# .envにDBパスワード設定
sed -i -e "s/DB_PASSWORD=/DB_PASSWORD=${MysqlRootPasswd}/g" .env

sudo chmod -R 777 storage
sudo chmod -R 775 bootstrap/cache


##
## laravel認証パッケージインストール
##
composer require laravel/ui:^1.0 --dev
php artisan ui bootstrap

curl -sL https://rpm.nodesource.com/setup_8.x | sudo bash -
sudo yum install --enablerepo=nodesource nodejs -y
npm install && npm run dev
php artisan ui vue --auth
php artisan migrate

# php-fpm を起動する
sudo systemctl restart php-fpm.service

# nginxを起動する
sudo systemctl restart nginx.service


# ipアドレスを表示
echo "http://$(curl ifconfig.me)"

