#!/bin/bash

# Баннер авторизации
hostnamectl set-hostname hq-cli.au-team.irpo

# Обновляем список пакетов
echo "Обновляем систему..."
apt-get update || { echo 'Ошибка обновления!'; exit 1; }

# Устанавливаем NFS client
echo "Устанавливаем NFS-client..."
apt-get install nfs-clients -y || { echo 'Ошибка установки NFS-common!'; exit 1; }

# Устанавливаем python3
echo "Устанавливаем python3"
apt-get install python3 -y || { echo 'Ошибка установки python3!'; exit 1; }



# Создаем точку монтирования
echo "Создаем точку монтирования..."
mkdir -p /mnt/nfs || { echo 'Ошибка создания директории!'; exit 1; }

# Редактируем /etc/fstab для автоматического монтирования
echo "Настраиваем автоматическое монтирование..."
cat <<EOF | tee -a /etc/fstab >&2
192.168.1.10:/raid5/nfs  /mnt/nfs  nfs  defaults  0  0
EOF

# Пробуем смонтировать раздел
echo "Монтируем раздел..."
mount -a && mount -v || { echo 'Ошибка монтирования!'; exit 1; }

# Тестовая запись файла
echo "Тестовая запись файла..."
touch /mnt/nfs/bbbbb || { echo 'Ошибка записи файла!'; exit 1; }

# Создаем пользователя SSH
echo "Создаем пользователя SSH..."
useradd sshuser -u 1010 || { echo 'Ошибка добавления пользователя!'; exit 1; }

# Проверяем данные пользователя
echo "Проверяем идентификатор пользователя..."
id sshuser

# Меняем пароль пользователя
echo "Меняем пароль пользователя..."
passwd sshuser

# Редактируем sudoers-файл
echo "Редактируем sudoers-файл..."
cat <<EOF | tee -a /etc/sudoers >&2
WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL
EOF

# Добавляем пользователя в группу wheel
echo "Добавляем пользователя в группу wheel..."
usermod -aG wheel sshuser || { echo 'Ошибка добавления в группу!'; exit 1; }

# Настраиваем sshd_config
echo "Настраиваем SSH-сервер..."
cat <<EOF | tee /etc/openssh/sshd_config >&2
Port 22
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF

# Создаем баннер авторизации
echo "Создаем баннер авторизации..."
sh -c 'echo "Authorized access only" > /root/banner'

# Активируем и перезапускаем SSH-сервис
echo "Перезапускаем SSH-сервис..."
systemctl enable --now sshd && systemctl restart sshd || { echo 'Ошибка запуска SSH!'; exit 1; }

# Устанавливаем браузер Яндекс
echo "Устанавливаем Яндекс Браузер..."
apt-get update && apt-get install yandex-browser-stable -y || { echo 'Ошибка установки Яндекс-Браузера!'; exit 1; }

# Настраиваем nameserver
echo "Настраиваем nameserver"
cat <<EOF | tee /etc/resolv.conf >&2
search au-team.irpo
nameserver 192.168.1.2
EOF

# Удаляем Python2.7
echo "Удаляем Python2.7"
rm /usr/bin/python2.7
