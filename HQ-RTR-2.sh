#!/bin/bash

# Редактирование конфигурационного файла resolv
echo "Редактируем resolv"
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF

# Настройка NAT перенаправления порта TCP 2024 на внутренний сервер
echo "Настраиваем NAT..."
iptables -t nat -A PREROUTING -p tcp -d 192.168.1.1 --dport 2024 -j DNAT --to-destination 192.168.1.10:2024
iptables-save > /etc/sysconfig/iptables

# Перезагрузка rc.local скрипта
echo "Перезагружаем rc.local..."
bash /etc/rc.local

mkdir /var/www
mkdir /var/www/html

# Редактирование конфигурационного файла Moodle
echo "Редактируем config.php..."
cat <<EOF > /var/www/html/config.php
\$CFG->wwwroot   = 'http://moodle.au-team.irpo';
EOF

# Установка Nginx веб-сервера
echo "Устанавливаем Nginx..."
apt-get update && apt-get install nginx -y

# Конфигурация прокси-серверов для доменов
echo "Создаем конфиг Nginx для виртуальных хостов..."
cat <<EOF > /etc/nginx/sites-available.d/proxy
server {
    listen 80;
    server_name moodle.au-team.irpo;
    location / {
        proxy_pass http://192.168.1.10:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
    }
}

server {
    listen 80;
    server_name wiki.au-team.irpo;
    location / {
        proxy_pass http://192.168.3.10:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
    }
}
EOF

# Удаляем дефолтные файлы конфигурации Nginx
echo "Удаляем стандартные конфиги..."
rm -f /etc/nginx/sites-available.d/default
rm -f /etc/nginx/sites-enabled.d/default

# Создаем символические ссылки для нового сайта
echo "Активируем новый сайт..."
ln -sf /etc/nginx/sites-available.d/proxy /etc/nginx/sites-enabled.d/

# Проверка файлов конфигурации
echo "Проверяем активированные сайты..."
ls -la /etc/nginx/sites-enabled.d

# Перезапуск Nginx
echo "Перезапускаем Nginx..."
systemctl restart nginx

#устанавливаем ipsec
apt-get update && apt-get install -y strongswan

#редактируем ipsec
echo "редактируем ipsec.conf"
сat <<EOF > /etc/strongswan/ipsec.conf

config setup

conn gre
	auto=start
	type=tunnel
	authby=secret
	left=10.0.0.1
	right=10.0.0.2
	leftsubnet=0.0.0.0/0
	rightsubnet=0.0.0.0/0
	leftprotoport=gre
	rightprotoport=gre
	ike=aes256-sha2_256-modp1024!
	esp=aes256-sha2_256!
EOF

#редактируем ipsec.secrets
echo "редактируем ipsec.secrets"
сat <<EOF > /etc/strongswan/ipsec.secrets
	10.0.0.1 10.0.0.2  : PSK "P@ssw0rd"
EOF

iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A INPUT  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i "ens19" -s "192.168.1.0/26" -j ACCEPT
iptables -A INPUT -i "ens19" -s "192.168.2.0/28" -j ACCEPT
iptables -A INPUT -i "ens19" -s "192.168.99.0/29" -j ACCEPT
iptables -A INPUT   -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT
iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -p tcp --dport 53 -j ACCEPT
iptables -A FORWARD -p udp --dport 123 -j ACCEPT
iptables -A INPUT -p udp --dport 67:68 --sport \ 67:68 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 631 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 631 -j ACCEPT
iptables -A FORWARD -p udp -m udp --dport 631 -j ACCEPT
iptables -A FORWARD -p tcp -m tcp --dport 631 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 514 -j ACCEPT
iptables -A FORWARD -m state --state NEW -m tcp -p tcp --dport 514 -j ACCEPT
iptables -A INPUT -m state --state NEW -m udp -p udp --dport 514 -j ACCEPT
iptables -A FORWARD -m state --state NEW -m udp -p udp --dport 514 -j ACCEPT
iptables -t nat -A POSTROUTING -o "ens18" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

 
# Редактирование конфигурационного файла resolv
echo "Редактируем resolv"
cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.1
EOF

echo "Настройки выполнены успешно!"
