#!/bin/bash

Init_Kubernetes() {
#	modprobe br_netfilter
	cat > /etc/sysctl.d/k8s.conf  <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
	sysctl -p /etc/sysctl.d/k8s.conf
	ls /proc/sys/net/bridge

	# Set kubernetes yum repo
	cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF

	yum makecache

	#Installing kubeadm, kubelet and kubectl
	yum install -y kubeadm-${KUBE_VERSION}-0.x86_64 \
		kubectl-${KUBE_VERSION}-0.x86_64 \
		kubelet-${KUBE_VERSION}-0.x86_64 \
		kubernetes-cni-${KUBERNETES_CNI}-0.x86_64

	systemctl enable kubelet
}


Install_Kubernetes_Master() {
	Init_Kubernetes
	
	images=(kube-proxy-amd64:v${KUBE_VERSION}
	kube-scheduler-amd64:v${KUBE_VERSION}
	kube-controller-manager-amd64:v${KUBE_VERSION}
	kube-apiserver-amd64:v${KUBE_VERSION}
	pause-amd64:${KUBE_PAUSE_VERSION}
	etcd-amd64:${ETCD_VERSION})
		
	for imageName in ${images[@]} ; do
	  docker pull $ALIYUN_URL/$imageName
	  docker tag $ALIYUN_URL/$imageName $GCR_URL/$imageName
	  docker rmi $ALIYUN_URL/$imageName
	done	

	# Using kubeadm to Create a Cluster
	kubeadm reset
	
	echo "It is neccesary to install a network addon, please choose one:"
	echo -e "\033[1m1. Flannel. \033[0m"
	echo -e "\033[1m2. Calico. \033[0m"
	while :
	do
		read -p 'Please Enter your choice: ' NETWORK_ADDON
		case $NETWORK_ADDON in 
			1)
			POD_NETWORK_CIDR=10.244.0.0/16
			break
			;;
			2)
			POD_NETWORK_CIDR=192.168.0.0/16
			break
			;;
		esac
	done

	cp $ROOTDIR/kubernetes.config $ROOTDIR/.config
	sed -i "s#%POD_NETWORK_CIDR%#${POD_NETWORK_CIDR}#g" $ROOTDIR/.config
	sed -i "s#%KUBE_VERSION%#v${KUBE_VERSION}#g" $ROOTDIR/.config
	ETCD_ENDPOINTS="\n$(docker exec etcd etcdctl member list | awk '{print $4}' | sed 's/clientURLs=/  - /g' | sed ':a;N;s/\n/\\n/g;ta')"
	sed -i "s#%ETCD_ENDPOINTS%#${ETCD_ENDPOINTS}#g" $ROOTDIR/.config
	
	kubeadm init --config $ROOTDIR/.config

	rm -rf $HOME/.kube/config
	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config

	case $NETWORK_ADDON in 
		1)
		wget -O $CONFDIR/kube-network-addon-flannel.yaml https://raw.githubusercontent.com/coreos/flannel/v$FLANNEL_VERSION/Documentation/kube-flannel.yml
		kubectl apply -f $CONFDIR/kube-network-addon-flannel.yaml
		break
		;;
		2)
		wget -O $CONFDIR/kube-network-addon-calico.yaml https://docs.projectcalico.org/v$CALICO_VERSION/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml
		kubectl apply -f $CONFDIR/kube-network-addon-calico.yaml
		# Add NetworkPolicy here
		break
		;;
	esac
}

Install_Kubernetes_Slave() {
	Init_Kubernetes

	images=(kube-proxy-amd64:v${KUBE_VERSION}
	pause-amd64:${KUBE_PAUSE_VERSION})
		
	for imageName in ${images[@]} ; do
	  docker pull $ALIYUN_URL/$imageName
	  docker tag $ALIYUN_URL/$imageName $GCR_URL/$imageName
	  docker rmi $ALIYUN_URL/$imageName
	done	

	# Using kubeadm to create a cluster
	kubeadm reset
	while :
	do
		read -p "Join cluster: " COMMAND
		if [ -n "$COMMAND" ]; then
			$COMMAND
			if [ $? -eq 0 ]; then
				break
			fi
		fi
	done
}
