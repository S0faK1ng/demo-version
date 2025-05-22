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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
    }
}

server {
    listen 80;
    server_name wiki.au-team.irpo;
    location / {
        proxy_pass http://192.168.3.10:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
    }
}
EOF

# Удаляем дефолтные файлы конфигурации Nginx
echo "Удаляем стандартные конфиги..."
rm -f /etc/nginx/sites-available.d/default
rm -f /etc/nginx/sites-enabled.d/default

# Создаем символические ссылки для нового сайта
echo "Активируем новый сайт..."
ln -s /etc/nginx/sites-available.d/proxy /etc/nginx/sites-enabled

# Проверка файлов конфигурации
echo "Проверяем активированные сайты..."
ls -la /etc/nginx/sites-enabled

# Перезапуск Nginx
echo "Перезапускаем Nginx..."
systemctl enable --now nginx
systemctl restart nginx

#устанавливаем ipsec
apt-get update && apt-get install -y strongswan

#редактируем ipsec
echo "редактируем ipsec.conf"
cat <<EOF > /etc/strongswan/ipsec.conf

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
cat <<EOF > /etc/strongswan/ipsec.secrets
	10.0.0.1 10.0.0.2  : PSK "P@ssw0rd"
EOF

cat <<EOF > backup.yml
---
- name: Collect network configurations from routers
  hosts: hq-rtr,br-rtr
  gather_facts: no
  tasks:
    - name: Ensure local target directory exists
      ansible.builtin.file:
        path: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/{{ item }}"
        state: directory
      loop:
        - "frr"
        - "sysconfig"
      delegate_to: localhost

    - name: Transfer FRR files to control node
      ansible.builtin.fetch:
        src: "/etc/frr/{{ item }}"
        dest: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/frr/"
        flat: yes
      loop:
        - "daemons"
        - "frr.conf"
        - "frr.conf.sav"
        - "vtysh.conf"
      become: yes

    - name: Transfer iptables configuration
      ansible.builtin.fetch:
        src: "/etc/sysconfig/{{ item }}"
        dest: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/sysconfig/"
        flat: yes
      loop:
        - "iptables"
        - "iptables_modules"
        - "iptables_params"
      become: yes

    - name: Interfaces archive
      ansible.builtin.archive:
        path: /etc/net/ifaces
        dest: /tmp/ifaces-{{ inventory_hostname }}.tar.gz
        format: gz

    - name: Transfer interfaces archive to control node
      ansible.builtin.fetch:
        src: "/tmp/ifaces-{{ inventory_hostname }}.tar.gz"
        dest: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/ifaces.tar.gz"
        flat: yes

    - name: Cleanup remote interfaces archive
      ansible.builtin.file:
        path: "/tmp/ifaces-{{ inventory_hostname }}.tar.gz"
        state: absent

    - name: Extract interfaces configuration locally
      ansible.builtin.unarchive:
        src: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/ifaces.tar.gz"
        dest: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/"
      delegate_to: localhost

    - name: Cleanup local archive
      ansible.builtin.file:
        path: "/etc/ansible/NETWORK_INFO/{{ inventory_hostname }}/ifaces.tar.gz"
        state: absent
      delegate_to: localhost
EOF

apt-get install -y rsyslog-classic
echo "*.* @@192.168.1.10:514" > /etc/rsyslog.d/all_log.conf
systemctl enable --now rsyslog
systemctl restart rsyslog
 
# Редактирование конфигурационного файла resolv
echo "Редактируем resolv"
cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.1
EOF

echo "Настройки выполнены успешно!"
