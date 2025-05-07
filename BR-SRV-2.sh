#!/bin/bash


# После перезагрузки создаем новых пользователей и групп в AD
samba-tool user create user1.hq 123qweR%
samba-tool user create user2.hq 123qweR%
samba-tool user create user3.hq 123qweR%
samba-tool user create user4.hq 123qweR%
samba-tool user create user5.hq 123qweR%

# Создаем новую группу HQ и добавляем туда всех пользователей
samba-tool group add hq
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq

# распаковка юзеров
unzip Users.zip

# запуск скрипта 
csv_file="/root/Users.csv"
while IFS=";" read -r firstName lastName role phone ou street zip city country password; do
	if [ "$firstName" == "First Name" ]; then
		continue
	fi
	username="${firstName,,}.${lastName,,}"
	samba-tool user add "$username" P@ssw0rd;
done < "$csv_file"


# Обновляем систему
apt-get update

# Устанавливаем утилиту синхронизации времени Systemd Timesyncd
apt-get install systemd-timesyncd -y

# Настройка синхронизации времени с внутренним источником
cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=172.16.4.2
EOF

# Активируем и запускаем службу TimeSync
systemctl enable --now systemd-timesyncd
timedatectl timesync-status

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

# Установка Ansible для автоматизации администрирования узлов сети
apt-get install ansible -y

# Создание структуры директорий Ansible
mkdir -p /etc/ansible

# Подготовка инвентаря Ansible
cat <<EOF > /etc/ansible/hosts
[hq]
hq-srv ansible_host=sshuser@192.168.1.10 ansible_port=2024
hq-cli ansible_host=sshuser@192.168.2.6 ansible_port=22
hq-rtr ansible_host=net_admin@192.168.1.1 ansible_port=22
br-rtr ansible_host=net_admin@192.168.4.1 ansible_port=22
EOF

# Настройки Python-интерпретатора для Ansible
cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
ansible_python_interpreter=/usr/bin/python3
EOF

# Генерация ключа RSA для авторизации по SSH
ssh-keygen -t rsa <<< "$(printf '%s\n' /root/.ssh/id_rsa)"

# Копирование публичного ключа на другие узлы
ssh-copy-id -p 22 net_admin@192.168.4.1
ssh-copy-id -p 22 sshuser@192.168.2.6
ssh-copy-id -p 2024 sshuser@192.168.1.10
ssh-copy-id -p 22 net_admin@192.168.1.1

# Тестируем подключение ко всем хостам
ansible all -m ping

# Установка и настройка Docker Engine
apt-get install docker-ce docker-engine docker-compose-v2 -y
systemctl enable --now docker
systemctl start docker

# Скачиваем образы MediaWiki и MariaDB
docker pull mediawiki
docker pull mariadb

# Конфигурация контейнера MediaWiki и базы данных
cat <<EOF > /root/wiki.yml
services:
  MediaWiki:
    image: mediawiki
    container_name: wiki
    restart: always
    ports:
      - 8080:80
    links:
      - database
    volumes:  
      - images:/var/www/html/images
      #- ./LocalSettings.php:/var/www/html/LocalSettings.php
  database:
    image: mariadb
    container_name: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: 123qweR%
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: WikiP@ssw0rd
    volumes: 
      - dbvolume:/var/lib/mysql
volumes:
  dbvolume:
      external: true
  images:
EOF

docker volume create dbvolume

docker volume ls

# Запускаем контейнеры
docker compose -f /root/wiki.yml up -d




# после настройки на hq-cli раскоментировать строчку 
      #- ./LocalSettings.php:/var/www/html/LocalSettings.php (nano wiki.yml)


#docker compose -f /root/wiki.yml up -d
