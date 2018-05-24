#!/bin/bash

systemctl stop firewalld
systemctl disable firewalld

swapoff -a 
sed -i 's/.*swap.*/#&/' /etc/fstab

setenforce  0 
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux 
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config 
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux 
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config  

read -p "Enter your hostname: " HOSTNAME
if [ -n "$HOSTNAME" ]; then
	hostnamectl set-hostname $HOSTNAME
else
	HOSTNAME=$(hostname)
fi	

# Grep ip
IPADDR=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | awk -F "/" '{print $1}')
if [ -z "`grep "$IPADDR $HOSTNAME" /etc/hosts`" ]; then
	echo "$IPADDR $HOSTNAME" >> /etc/hosts
fi

yum update -y
yum install -y epel-release
yum install -y wget ntp

mkdir -p /var/data/cron
echo '*/30 * * * * /usr/sbin/ntpdate time7.aliyun.com >/dev/null 2>&1' > /var/data/cron/crontab.1
crontab /var/data/cron/crontab.1
