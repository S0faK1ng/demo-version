#!/bin/bash

# Создаем директории для интерфейсов
mkdir -p /etc/net/ifaces/ens18
mkdir -p /etc/net/ifaces/ens19
mkdir -p /etc/net/ifaces/ens19.100
mkdir -p /etc/net/ifaces/ens19.200
mkdir -p /etc/net/ifaces/ens19.999
mkdir -p /etc/net/ifaces/iptunnel

# Настраиваем интерфейс ens18 (статический IP)
cat <<EOF > /etc/net/ifaces/ens18/options
BOOTPROTO=static
TYPE=eth
EOF

cat <<EOF > /etc/net/ifaces/ens18/ipv4address
172.16.4.2/28
EOF

cat <<EOF > /etc/net/ifaces/ens18/ipv4route
default via 172.16.4.1
EOF

# Настраиваем интерфейс ens19 (статический IP)
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
EOF

# Настраиваем VLAN ens19.100
cat <<EOF > /etc/net/ifaces/ens19.100/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=100
EOF

cat <<EOF > /etc/net/ifaces/ens19.100/ipv4address
192.168.1.1/26
EOF

# Настраиваем VLAN ens19.200
cat <<EOF > /etc/net/ifaces/ens19.200/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=200
EOF

cat <<EOF > /etc/net/ifaces/ens19.200/ipv4address
192.168.2.1/28
EOF

# Настраиваем VLAN ens19.999
cat <<EOF > /etc/net/ifaces/ens19.999/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=999
EOF

cat <<EOF > /etc/net/ifaces/ens19.999/ipv4address
192.168.99.1/29
EOF

# Настраиваем iptunnel
cat <<EOF > /etc/net/ifaces/iptunnel/ipv4address
10.0.0.1/28
EOF

cat <<EOF > /etc/net/ifaces/iptunnel/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.4.2
TUNREMOTE=172.16.5.2
TUNOPTIONS='ttl 64'
EOF

cat <<EOF > /etc/net/ifaces/iptunnel/ipv4route
192.168.4.0/24 via 10.0.0.2
EOF

# Включаем форвардинг пакетов
sed -i '/^net\.ipv4\.ip_forward=/d' /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Очищаем существующие правила iptables и настраиваем NAT
iptables -F
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# Перезапускаем сеть
service network restart

# Настраиваем DNS
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF

# Обновляем пакеты и устанавливаем dnsmasq
apt-get update
apt-get install dnsmasq

# Настраиваем dnsmasq
cat <<EOF > /etc/dnsmasq.conf
no-resolv
domain=au-team.irpo
dhcp-range=192.168.2.2,192.168.2.15,999h
dhcp-option=3,192.168.2.1
dhcp-option=6,192.168.1.2
interface=ens19.200
EOF

# Перезапускаем dnsmasq
systemctl restart dnsmasq
systemctl status dnsmasq

# Создаем пользователя net_admin
useradd net_admin -m
passwd net_admin

# Добавляем пользователя в sudoers
echo 'net_admin ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

# Настраиваем chrony
apt-get install chrony
cat <<EOF > /etc/chrony.conf
local stratum 5
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.5.0/28
allow 192.168.4.0/27
EOF

systemctl enable --now chrony
systemctl restart chrony
timedatectl set-ntp 0
timedatectl

# Настраиваем SSH
apt-get install openssh-server
cat <<EOF > /etc/openssh/sshd_config
Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner
EOF

cat <<EOF > /root/banner
Authorized access only
EOF

systemctl enable --now sshd
systemctl restart sshd
