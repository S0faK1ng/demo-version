#!/bin/bash

iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.10:8080
iptables-save > /etc/sysconfig/iptables
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.10:2024
iptables-save > /etc/sysconfig/iptables
