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
        proxy_pass http://192.168.4.10:8080;
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

# Редактирование конфигурационного файла resolv
echo "Редактируем resolv"
cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.1
EOF

echo "Настройки выполнены успешно!"
