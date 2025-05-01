#!/bin/bash

#обновляем пакеты
apt-get update

# Создаем нового пользователя с UID 1010
useradd sshuser -u 1010

# Проверяем идентификатор пользователя
id sshuser

# Устанавливаем пароль для пользователя sshuser
echo 'P@ssw0rd' | passwd --stdin sshuser

# Редактируем файл sudoers, разрешая пользователям группы WHEEL выполнять команды без пароля
echo '%WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

# Добавляем пользователя sshuser в группу WHEEL
usermod -aG wheel sshuser

# Настраиваем SSH
cat <<EOF > /etc/openssh/sshd_config
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF

# Создаем файл баннера входа
cat <<EOF > /root/banner
Authorized access only

EOF

# Включаем службу SSH сразу и автоматически при загрузке системы
systemctl enable --now sshd
systemctl restart sshd

# Удаляем предустановленный BIND
apt-get remove bind9 -y

# Устанавливаем сервер Samba Active Directory Domain Controller
apt-get install task-samba-dc -y

# Обновляем файл resolv.conf, оставляя локальную запись DNS
cat <<EOF > /etc/resolv.conf
domain ak.local
nameserver 8.8.8.8
nameserver 127.0.0.1
EOF


# Очищаем старую конфигурацию Samba
rm -rf /etc/samba/smb.conf

# Изменяем имя хоста на требуемое значение
hostnamectl set-hostname br-srv.au-team.irpo

# Обновляем hosts-файл
cat <<EOF > /etc/hosts
192.168.4.10	br-srv.au-team.irpo
EOF

# Создаем новую доменную структуру с использованием samba-tool
samba-tool domain provision

# Перемещаем конфиг KRB5 в нужный каталог
mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf

# Запускаем службы Samba и добавляем их в автозагрузку
systemctl enable smb
systemctl start smb

# Создаем дополнительные файлы автозапуска
cat <<EOF > /etc/rc.d/rc.local
#!/bin/sh -e
systemctl restart network
systemctl restart samba
exit 0
EOF

# Предоставляем права на выполнение файла rc.local
chmod +x /etc/rc.d/rc.local

# Перезагрузка системы для применения изменений
reboot

# После перезагрузки создаем новых пользователей и групп в AD
samba-tool user create user1.hq 123qweR%
samba-tool user create user2.hq 123qweR%
samba-tool user create user3.hq 123qweR%
samba-tool user create user4.hq 123qweR%
samba-tool user create user5.hq 123qweR%

# Создаем новую группу HQ и добавляем туда всех пользователей
samba-tool group add hq
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq

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

# Установка Ansible для автоматизации администрирования узлов сети
apt-get install ansible -y

# Создание структуры директорий Ansible
mkdir -p /etc/ansible

# Подготовка инвентаря Ansible
cat <<EOF > /etc/ansible/hosts
[hq]
hq-srv ansible_host=sshuser@192.168.1.10 ansible_port=2024
hq-cli ansible_host=sshuser@192.168.2.10 ansible_port=2024
hq-rtr ansible_host=net_admin@192.168.1.1 ansible_port=2024
br-rtr ansible_host=net_admin@192.168.4.1 ansible_port=2024
EOF

# Настройки Python-интерпретатора для Ansible
cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
ansible_python_interpreter=/usr/bin/python3
EOF

# Генерация ключа RSA для авторизации по SSH
ssh-keygen -t rsa

# Копирование публичного ключа на другие узлы
ssh-copy-id -p 22 net_admin@192.168.4.1
ssh-copy-id -p 2024 sshuser@192.168.2.10
ssh-copy-id -p 2024 sshuser@192.168.1.10
ssh-copy-id -p 22 net_admin@192.168.1.1

# Тестируем подключение ко всем хостам
ansible all -m ping

# Установка и настройка Docker Engine
apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl enable --now docker
systemctl status docker

# Скачиваем образы MediaWiki и MariaDB
docker pull mediawiki
docker pull mariadb

# Конфигурация контейнера MediaWiki и базы данных
cat <<EOF > /root/wiki.yml
version: '3'
services:
  mariadb:
    image: mariadb
    container_name: mariadb
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 123qweR%
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: 123qweR%
    volumes:
      - mariadb_data:/var/lib/mysql
  wiki:
    image: mediawiki
    container_name: wiki
    restart: always
    depends_on:
      - mariadb
    environment:
      MEDIAWIKI_DB_HOST: mariadb
      MEDIAWIKI_DB_USER: wiki
      MEDIAWIKI_DB_PASSWORD: 123qweR%
      MEDIAWIKI_DB_NAME: mediawiki
    ports:
      - "8080:80"
volumes:
  mariadb_data:
EOF

# Запускаем контейнеры
docker-compose -f /root/wiki.yml up -d

# Удаление старого LocalSettings.php и перенос текущего в новое местоположение
rm -rf /root/LocalSettings.php
mkdir /root/mediawiki
mv /home/sshuser/LocalSettings.php /root/mediawiki/

# Финальная сборка докера
docker-compose -f /root/wiki.yml up -d

