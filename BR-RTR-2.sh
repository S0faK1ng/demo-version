#!/bin/bash

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
	left=10.0.0.2
	right=10.0.0.1
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

apt-get install -y rsyslog-classic
echo "*.* @@192.168.1.10:514" > /etc/rsyslog.d/all_log.conf
systemctl enable --now rsyslog
systemctl restart rsyslog

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
iptables -A INPUT -i "ens19" -s "192.168.3.0/27" -j ACCEPT
iptables -A INPUT   -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT
iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -p tcp --dport 53 -j ACCEPT
iptables -A FORWARD -p udp --dport 123 -j ACCEPT
iptables -t nat -A POSTROUTING -o "ens18" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables


#iptables -t nat -A PREROUTING -p tcp -d 192.168.3.1 --dport 80 -j DNAT --to-destination 192.168.3.10:8080
#iptables -t nat -A PREROUTING -p tcp -d 192.168.3.1 --dport 2024 -j DNAT --to-destination 192.168.3.10:2024
#iptables-save > /etc/sysconfig/iptables
