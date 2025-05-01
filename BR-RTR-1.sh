mkdir /etc/net/ifaces/ens19
mkdir /etc/net/ifaces/iptunnel

cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF

cat <<EOF > /etc/net/ifaces/ens19/ipv4address

192.168.4.1/28

EOF

cat <<EOF > /etc/net/ifaces/iptunnel/ipv4address

10.0.0.2/28

EOF

cat <<EOF > /etc/net/ifaces/iptunnel/options

TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.5.2
TUNREMOTE=172.16.4.2
TUNOPTIONS='ttl 64'

EOF

cat <<EOF > /etc/net/ifaces/iptunnel/ipv4route

192.168.1.0/24 via 10.0.0.1
192.168.2.0/24 via 10.0.0.1

EOF

cat <<EOF > /etc/net/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
EOF

sysctl -p

iptables -F
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

service network restart

# Добавляем IPTABLES в автозапуск
systemctl enable iptables
systemctl start iptables

useradd net_admin -m
passwd net_admin

# Добавляем пользователя в sudoers
echo 'net_admin ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

apt-get remove ntp

apt-get remove chrony

apt-get update

apt-get install systemd-timesyncd

nano /etc/systemd/timesyncd.conf

[Time]
NTP=172.16.4.2

systemctl enable --now systemd-timesyncd

apt-get update

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

# Переименовываем машину
hostnamectl set-hostname br-rtr.au-team.irpo
