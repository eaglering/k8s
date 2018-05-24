#!/bin/bash

while :
do
	echo "What do you want to uninstall?"
	echo "1.Etcd."
	echo "1.Dashboard."
	echo "2.Ingress nginx."
	echo "3.Kubernetes."
	echo "q.Exit."
	read -p "Enter your choice: " choice
	case $choice in
		1)
		docker rm -f etcd
		1) 
		kubectl delete -f https://raw.githubusercontent.com/eaglering/k8s/v1.10.2/dashboard-amd64/kubernetes-dashboard.yaml
		break
		;;
		2)
		kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/namespace.yaml
		break
		;;
		3)
		kubeadm reset
		rm -rf /var/lib/cni /var/lib/calico /op/cni/bin
		ip link delete cni0
		ip link delete flannel.1
		break
		;;
		q)
		break
		;;
	esac
done