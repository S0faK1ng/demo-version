#!/bin/bash

# Создаем необходимые директории для сетевых интерфейсов
mkdir /etc/net/ifaces/ens19
mkdir /etc/net/ifaces/iptunnel

# Настройка ethernet-интерфейса ens19
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
CONFIG_WIRELANDS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF

# IP адрес ethernet-интерфейса ens19
cat <<EOF > /etc/net/ifaces/ens19/ipv4address
192.168.4.1/28
EOF

# Настройки GRE-туннеля
cat <<EOF > /etc/net/ifaces/iptunnel/ipv4address
10.0.0.2/28
EOF

cat <<EOF > /etc/net/ifaces/iptunnel/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.5.2
TUNREMOTE=172.16.4.2
TUNOPTIONS='ttl 64'
EOF

# Маршруты через туннель
cat <<EOF > /etc/net/ifaces/iptunnel/ipv4route
192.168.1.0/24 via 10.0.0.1
192.168.2.0/24 via 10.0.0.1
EOF

# Настраиваем sysctl для IPv4 forwarding и безопасности сети
cat <<EOF > /etc/net/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
EOF

# Применяем изменения sysctl
sysctl -p

# Очищаем правила iptables и настраиваем NAT
iptables -F
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# Перезагружаем сеть
service network restart

# Включаем службу iptables
systemctl enable iptables
systemctl start iptables

# Создаем администратора сети
useradd net_admin -m
passwd net_admin

# Даем права sudo новому пользователю
echo 'net_admin ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

# Удаляем старые сервисы синхронизации времени
apt-get remove ntp -y
apt-get remove chrony -y

# Обновляем список пакетов
apt-get update

# Устанавливаем новый сервис синхронизации времени
apt-get install systemd-timesyncd -y

# Конфигурируем timesyncd
cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=172.16.4.2
EOF

# Запускаем и включаем timesyncd
systemctl enable --now systemd-timesyncd

# Обновляем репозитории и устанавливаем OpenSSH сервер
apt-get update

# Настраиваем SSH-сервер
cat <<EOF > /etc/openssh/sshd_config
Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner
EOF

# Баннер авторизации
cat <<EOF > /root/banner
Authorized access only
EOF

# установка хрони
apt-get install chony -y

#настройка хрони
cat <<EOF > /etc/chrony.conf
pool 172.16.4.2 iburst
driftfile /var/lib/chrony/drift
makestep
rtcsync
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony

#запуск хрони
systemctl enable --now chronyd
systemctl restart chronyd

# Переименовать машину
hostnamectl set-hostname br-rtr.au-team.irpo

# Активируем и перезапускаем SSH-сервис
systemctl enable --now sshd
systemctl restart sshd


