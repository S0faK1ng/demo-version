#!/bin/bash

#обновляем пакеты
apt-get update

# Создаем нового пользователя с UID 1010
useradd sshuser -u 1010

# Проверяем идентификатор пользователя
id sshuser

# Устанавливаем пароль для пользователя sshuser
passwd sshuser

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
