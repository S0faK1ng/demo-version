#!/bin/bash

# Настройка NAT перенаправления порта TCP 2024 на внутренний сервер
echo "Настраиваем NAT..."
iptables -t nat -A PREROUTING -p tcp -d 192.168.1.1 --dport 2024 -j DNAT --to-destination 192.168.1.10:2024

# Очистка правил NAT
echo "Очищаем правила NAT..."
iptables -F -t nat

# Перезагрузка rc.local скрипта
echo "Перезагружаем rc.local..."
bash /etc/rc.local

mkdir /var/www/html/

# Редактирование конфигурационного файла Moodle
echo "Редактируем config.php..."
nano /var/www/html/config.php << EOF
<?php
\$CFG->wwwroot   = 'http://moodle.au-team.irpo';
EOF

# Установка Nginx веб-сервера
echo "Устанавливаем Nginx..."
apt update && apt install nginx -y

# Конфигурация прокси-серверов для доменов
echo "Создаем конфиг Nginx для виртуальных хостов..."
cat > /etc/nginx/sites-available/proxy << EOF
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
rm -f /etc/nginx/sites-available/default
rm -f /etc/nginx/sites-enabled/default

# Создаем символические ссылки для нового сайта
echo "Активируем новый сайт..."
ln -sf /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/

# Проверка файлов конфигурации
echo "Проверяем активированные сайты..."
ls -la /etc/nginx/sites-enabled

# Перезапуск Nginx
echo "Перезапускаем Nginx..."
systemctl restart nginx

echo "Настройки выполнены успешно!"
