#!/bin/bash

# Создаем директории для интерфейсов
mkdir -p /etc/net/ifaces/{ens19,ens20}

# Настраиваем интерфейс ens18 (DHCP)
cat <<EOF > /etc/net/ifaces/ens18/options
BOOTPROTO=dhcp
TYPE=eth
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF

# Настраиваем интерфейс ens19 (статический IP)
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF

# Настраиваем интерфейс ens20 (статический IP)
cat <<EOF > /etc/net/ifaces/ens20/options
BOOTPROTO=static
TYPE=eth
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF

# Устанавливаем статические адреса для интерфейсов
echo '172.16.4.1/28' > /etc/net/ifaces/ens19/ipv4address
echo '172.16.5.1/28' > /etc/net/ifaces/ens20/ipv4address

# Включаем форвардинг пакетов
cat <<EOF > /etc/net/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
EOF

sysctl -p

# Очищаем существующие правила iptables и настраиваем NAT
iptables -F
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# Перезапускаем сеть
service network restart

# Добавляем IPTABLES в автозапуск
systemctl enable iptables
systemctl start iptables

# Разрешаем root доступ по SSH
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/openssh/sshd_config

# Перезапускаем сервис SSHD
systemctl restart sshd.service

# Переименовываем машину
hostnamectl set-hostname isp.au-team.irpo

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

# Перезагружаем машину
reboot
