#!/bin/bash

# Создаем директории для интерфейсов
mkdir -p /etc/net/ifaces/{ens19,ens20}

# Настраиваем интерфейс ens18 (DHCP)
cat <<EOF > /etc/net/ifaces/ens18/options
BOOTPROTO=dhcp
TYPE=eth
EOF

# Настраиваем интерфейс ens19 (статический IP)
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
EOF

# Настраиваем интерфейс ens20 (статический IP)
cat <<EOF > /etc/net/ifaces/ens20/options
BOOTPROTO=static
TYPE=eth
EOF

# Устанавливаем статические адреса для интерфейсов
echo '172.16.4.1/28' > /etc/net/ifaces/ens19/ipv4address
echo '172.16.5.1/28' > /etc/net/ifaces/ens20/ipv4address

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

# Разрешаем root доступ по SSH
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Перезапускаем сервис SSHD
systemctl restart sshd.service
