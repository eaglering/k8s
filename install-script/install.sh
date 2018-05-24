#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ROOTDIR=$(dirname $0)
WORKDIR=$HOME/eaglering-cluster

BINDIR=$WORKDIR/bin
LOGDIR=$WORKDIR/log
CERTDIR=$WORKDIR/cert
CONFDIR=$WORKDIR/conf
DATADIR=$WORKDIR/data

mkdir -p $BINDIR
mkdir -p $LOGDIR
mkdir -p $CERTDIR
mkdir -p $CONFDIR
mkdir -p $DATADIR

$ROOTDIR/src/env.sh

. $ROOTDIR/src/const.sh
. $ROOTDIR/src/etcd.sh
. $ROOTDIR/src/kubernetes.sh
. $ROOTDIR/src/ingress-nginx.sh
. $ROOTDIR/src/docker-redis-cluster.sh
. $ROOTDIR/src/mariadb.sh

#Installing Docker
yum install -y docker

systemctl enable docker
systemctl start docker
	
while :
do
	echo "Installing etcd?"
	echo "1.master."
	echo "2.node."
	echo "q.exit."
	read -p "Enter your choice: " choice
	case $choice in
		1) 
		Install_Etcd_Master
		break
		;;
		2)
		Install_Etcd_Slave
		break
		;;
		q)
		break
		;;
	esac
done

while :
do
	echo "Installing kubernetes?"
	echo "1.master."
	echo "2.node."
	echo "q.exit."
	read -p "Enter your choice: " choice
	case $choice in
		1) 
		Install_Kubernetes_Master
		break
		;;
		2)
		Install_Kubernetes_Slave
		break
		;;
		q)
		break
		;;
	esac
done

while :
do
	read -p "Install ingress-nginx?[Y/n]? " choice
	case $choice in
		Y) 
		Install_Ingress_Nginx
		break
		;;
		n)
		break
		;;
	esac
done

while :
do
	read -p "Install ingress dashboard?[Y/n]? " choice
	case $choice in
		Y) 
		Install_Ingress_Dashboard
		break
		;;
		n)
		break
		;;
	esac
done

while :
do
	read -p "Install redis cluster?[Y/n]? " choice
	case $choice in
		Y) 
		Install_Redis_Cluster
		break
		;;
		n)
		break
		;;
	esac
done

while :
do
	read -p "Install mariadb cluster?[Y/n]? " choice
	case $choice in
		Y) 
		Install_Mariadb
		break
		;;
		n)
		break
		;;
	esac
done
