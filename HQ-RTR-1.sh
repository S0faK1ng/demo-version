
nano /etc/net/ifaces/ens18/options

    BOOTPROTO=static
    TYPE=eth

nano /etc/net/ifaces/ens18/ipv4address

  172.16.4.2/28

nano /etc/net/ifaces/ens18/ipv4route

  default via 172.16.4.1

mkdir /etc/net/ifaces/ens19
mkdir /etc/net/ifaces/ens19.100
mkdir /etc/net/ifaces/ens19.200
mkdir /etc/net/ifaces/ens19.999

nano /etc/net/ifaces/ens19/options

   BOOTPROTO=static
   TYPE=eth

nano /etc/net/ifaces/ens19.100/options

   BOOTPROTO=static
   TYPE=vlan
   HOST=ens19
   VID=100

nano /etc/net/ifaces/ens19.100/ipv4address

 192.168.1.1/26

nano /etc/net/ifaces/ens19.200/options

   BOOTPROTO=static
   TYPE=vlan
   HOST=ens19
   VID=200

nano /etc/net/ifaces/ens19.200/ipv4address

 192.168.2.1/28

nano /etc/net/ifaces/ens19.999/options

   BOOTPROTO=static
   TYPE=vlan
   HOST=ens19
   VID=999

nano /etc/net/ifaces/ens19.999/ipv4address

 192.168.99.1/29

mkdir /etc/net/ifaces/iptunnel

nano /etc/net/ifaces/iptunnel/ipv4address

10.0.0.1/28

nano /etc/net/ifaces/iptunnel/options

TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.4.2
TUNREMOTE=172.16.5.2
TUNOPTIONS='ttl 64'

nano /etc/net/ifaces/iptunnel/ipv4route

192.168.4.0/24 via 10.0.0.2

nano /etc/net/sysctl.conf

 ipv4.net.forward=1

iptables -F
iptables -t nat -A POSTROUTING  -o ens18 -j MASQUERADE
iptables-save

service network restart

nano /etc/resolv.conf

apt-get update

apt-get install dnsmasq

nano /etc/dnsmasq.conf

no-resolv
domain=au-team.irpo
dhcp-range=192.168.2.2,192.168.2.15,999h
dhcp-option=3,192.168.2.1
dhcp-option=6,192.168.1.2
interface=ens19.200

systemctl restart dnsmasq

systemctl status dnsmasq

useradd net_admin -m

passwd net_admin

P@$$word

nano /etc/sudoers

net_admin ALL=(ALL:ALL) NOPASSWD: ALL

nano /etc/resolv.conf

nameserver 8.8.8.8

apt-get update

apt-get install chrony

systemctl status chrony

timedatectl

nano /etc/chrony.conf

local stratum 5
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.5.0/28
allow 192.168.4.0/27
#pool
#rtcsync

systemctl enable --now chrony

systemctl restart chrony

timedatectl set-ntp 0

timedatectl

apt-get update

apt-get install ssh-server

nano /etc/openssh/sshd_config

Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner

nano /root/banner

Authorized access only


systemctl enable --now sshd 

systemctl restart sshd
