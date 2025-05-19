#!/bin/bash

# Переименовали
hostnamectl set-hostname hq-srv.au-team.irpo

# Обновление списка пакетов
apt-get update

# Установка пакета DNSmasq
apt-get install dnsmasq -y

# Редактирование файла конфигурации DNSmasq
cat <<EOF > /etc/dnsmasq.conf
no-resolv
domain=au-team.irpo
server=/au-team.irpo/192.168.3.10
server=8.8.8.8
interface=ens18
address=/hq-rtr.au-team.irpo/192.168.1.1
ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo
cname=moodle.au-team.irpo,hq-rtr.au-team.irpo
cname=wiki.au-team.irpo,hq-rtr.au-team.irpo
address=/br-rtr.au-team.irpo/192.168.3.1
address=/hq-srv.au-team.irpo/192.168.1.10
ptr-record=10.1.168.192.in-addr.arpa,hq-srv.au-team.irpo
address=/hq-cli.au-team.irpo/192.168.2.6
ptr-record=6.2.168.192.in-addr.arpa,hq-cli.au-team.irpo
address=/br-srv.au-team.irpo/192.168.3.10
EOF

cat <<EOF > /etc/hosts
127.0.0.1       localhost.localdomain localhost
::1       localhost6.localdomain localhost6
192.168.1.1       hq-rtr.au-team.irpo
EOF

# Рестарт службы DNSmasq
systemctl enable --now dnsmasq
systemctl restart dnsmasq

# Создание пользователя для SSH
useradd sshuser -u 1010
id sshuser
passwd sshuser

# Предоставление прав sudo пользователю
echo 'WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers
usermod -aG wheel sshuser

# Изменение настроек SSH
cat <<EOF > /etc/openssh/sshd_config
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF

# Создание баннера для SSH
cat <<EOF > /root/banner
Authorized access only
EOF

# Запуск и включение SSH
systemctl enable --now sshd
systemctl restart sshd

# Проверка дисков
lsblk

# Создание RAID5 массива
mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sd[b-d]

# Просмотр состояния RAID массива
cat /proc/mdstat

# Сохранение информации о массиве
mdadm --detail -scan > /etc/mdadm.conf

# Форматирование раздела
fdisk /dev/md0 <<< "$(printf '%s\n' n p 1 2048 4186111 w)"

# Создание файловой системы
mkfs.ext4 /dev/md0p1

# Монтируем созданный раздел
echo '/dev/md0p1 /raid5 ext4 defaults 0 0' > /etc/fstab
mkdir /raid5
mount -a

# Установка NFS сервера
apt-get install nfs-server -y

# Подготовка каталога для экспорта
mkdir /raid5/nfs
chown 99:99 /raid5/nfs
chmod 777 /raid5/nfs

# Настройка экспорта NFS
cat <<EOF > /etc/exports
/raid5/nfs 192.168.2.0/28(rw,sync,no_subtree_check)
EOF

# Экспорт ресурсов NFS
exportfs -a
exportfs -v

# Перезапуск NFS
systemctl enable --now nfs
systemctl restart nfs

# Установка служб времени
#apt-get install systemd-timesyncd -y

# Настройка службы времени
#cat <<EOF > /etc/systemd/timesyncd.conf
#[Time]
#NTP=192.168.1.1
#EOF

# установка хрони
apt-get install chrony -y

#настройка хрони
cat <<EOF > /etc/chrony.conf
pool 172.16.4.2 iburst
driftfile /var/lib/chrony/drift
makestep
rtcsync
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
EOF

#запуск хрони
systemctl enable --now chronyd
systemctl restart chronyd

# Установка веб-сервера Apache, PHP и MySQL
apt-get install apache2 php8.2 apache2-mod_php8.2 mariadb-server \
php8.2-opcache php8.2-curl php8.2-gd php8.2-intl php8.2-mysqli \
php8.2-xml php8.2-xmlrpc php8.2-ldap php8.2-zip php8.2-soap \
php8.2-mbstring php8.2-json php8.2-xmlreader php8.2-fileinfo php8.2-sodium -y

# Запуск Apache и MySQL
systemctl enable --now httpd2 mysql mysqld
service mysqld start

# Безопасная настройка MySQL
mysql_secure_installation

# Вход в базу данных MySQL
mysql -u root -p

# Скачивание и распаковка архива Moodle
curl -L https://github.com/moodle/moodle/archive/refs/tags/v4.5.0.zip > /root/moodle.zip
unzip /root/moodle.zip -d /var/www/html
mv /var/www/html/moodle-4.5.0/* /var/www/html/

# Настройка каталогов Moodle
mkdir /var/www/moodledata
chown apache2:apache2 /var/www/html
chown apache2:apache2 /var/www/moodledata

# Оптимизация настроек PHP
sed -i 's/max_input_vars = .*/max_input_vars = 5000/' /etc/php/8.2/apache2-mod_php/php.ini

# Убираем дефолтный индекс HTML
rm /var/www/html/index.html

# Перезапуск Apache
systemctl restart httpd2


apt-get install -y rsyslog-classic


cat <<EOF > /etc/rsyslog.d/00_common.conf
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port=514")

module(load="builtin:omfile" Template="RSYSLOG_TraditionalFileFormat"
       DirCreateMode="0755"
       FileCreateMode="0640"
       fileOwner="root"
       fileGroup="adm")

global(workDirectory="/var/spool/rsyslog")

# start log rotation via outchannel
# outchannel definition
$outchannel log_rotation,/opt/%HOSTNAME%/log_rotation.log, 52428800,/home/me/./log_rotation_script
#  activate the channel and log everything to it
*.* :omfile:$log_rotation
# end log rotation via outchannel

$template RemoteLogs,"/opt/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
EOF

cat <<EOF > /opt/log_rotation_script.sh
mv -f /opt/%HOSTNAME%/log_rotation.log /opt/%HOSTNAME%/log_rotation.log.1
EOF

systemctl enable --now rsyslog
systemctl retart rsyslog
