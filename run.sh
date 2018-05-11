#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

systemctl stop firewalld
systemctl disable firewalld

swapoff -a 
sed -i 's/.*swap.*/#&/' /etc/fstab

setenforce  0 
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux 
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config 
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux 
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config  

modprobe br_netfilter
cat <<EOF >  /etc/sysctl.d/k8s.conf
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

yum install -y epel-release
yum install -y wget ntpdate

mkdir -p /var/data/cron
systemctl enable ntpdate.service
echo '*/30 * * * * /usr/sbin/ntpdate time7.aliyun.com >/dev/null 2>&1' > /var/data/cron/crontab.1
crontab /var/data/cron/crontab.1
systemctl start ntpdate.service
 
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "* soft nproc 65536"  >> /etc/security/limits.conf
echo "* hard nproc 65536"  >> /etc/security/limits.conf
echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
echo "* hard memlock  unlimited"  >> /etc/security/limits.conf

#Installing Docker
yum install -y docker

systemctl enable docker
systemctl start docker

KUBE_VERSION=1.10.2
KUBERNETES_CNI=0.6.0
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.1.12
DNS_VERSION=1.14.10
FLANNEL_VERSION=0.10.0
DEFAULT_BACKEND_VERSION=1.4
NGINX_INGRESS_CONTROLLER_VERSION=0.14.0

#Installing kubeadm, kubelet and kubectl
yum install -y kubeadm-${KUBE_VERSION}-0.x86_64 \
	kubectl-${KUBE_VERSION}-0.x86_64 \
	kubelet-${KUBE_VERSION}-0.x86_64 \
	kubernetes-cni-${KUBERNETES_CNI}-0.x86_64


	

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# Using kubeadm to Create a Cluster
kubeadm reset
kubeadm init --apiserver-advertise-address=$IPADDR --kubernetes-version=v$KUBE_VERSION --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors 'Swap' | tee k8s_for_CentOS.log



----------------------------------------------	
	
	
#Disabling SELinux
setenforce 0

#Some users on RHEL/CentOS 7 have reported issues with traffic being routed incorrectly due to iptables being bypassed.
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

#Configure cgroup driver used by kubelet on Master Node
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf	

# Configure the base image of pod
KUBEADM_CONF=/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
result=$(cat $KUBEADM_CONF | grep 'KUBELET_EXTRA_ARGS=')
if [ -n result ] ; then
	KUBELET_EXTRA_ARGS="--fail-swap-on=false"
	sed -i "/Environment=\"KUBELET_CERTIFICATE_ARGS/a\Environment=\"KUBELET_EXTRA_ARGS=--fail-swap-on=false\"" $KUBEADM_CONF
fi

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# Using kubeadm to Create a Cluster
kubeadm reset
kubeadm init --apiserver-advertise-address=$IPADDR --kubernetes-version=v$KUBE_VERSION --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors 'Swap' | tee k8s_for_CentOS.log

#---------------------------------------------------------------------------
GCR_URL=gcr.io/google_containers
ALIYUN_URL="registry.cn-shenzhen.aliyuncs.com/eaglering"

images=(kube-proxy-amd64:v${KUBE_VERSION}
kube-scheduler-amd64:v${KUBE_VERSION}
kube-controller-manager-amd64:v${KUBE_VERSION}
kube-apiserver-amd64:v${KUBE_VERSION}
pause-amd64:${KUBE_PAUSE_VERSION}
etcd-amd64:${ETCD_VERSION}
k8s-dns-sidecar-amd64:${DNS_VERSION}
k8s-dns-kube-dns-amd64:${DNS_VERSION}
k8s-dns-dnsmasq-nanny-amd64:${DNS_VERSION})

##############################################################
#                Make yourself's registry                    #
##############################################################
# for imageName in ${images[@]} ; do
#   docker pull $GCR_URL/$imageName
#   docker tag $GCR_URL/$imageName $ALIYUN_URL/$imageName
#   docker push $ALIYUN_URL/$imageName
#   docker rmi $ALIYUN_URL/$imageName
# done

for imageName in ${images[@]} ; do
  docker pull $ALIYUN_URL/$imageName
  docker tag $ALIYUN_URL/$imageName $GCR_URL/$imageName
  docker rmi $ALIYUN_URL/$imageName
done

echo
echo "Which type of server do you want?"
echo -e "\033[1m1. Master. \033[0m"
echo -e "\033[1m2. Node. \033[0m"
echo -e "\033[1m3. None \033[0m"
while :
do
	read -p 'Please Enter your choice: ' choice
	case $choice in 
		1)
		echo 
		echo 'Choose ip?'
		INET_IPS=($(ip addr | grep 'inet ' | awk '{print $2}' | awk -F / '{print $1}'))

		for i in `seq 1 ${#INET_IPS[@]}`
		do
			echo -n -e "\033[1m ${i} : ${INET_IPS[$i-1]}"
			[ $i == 1 ] && echo -n -e "\033[1;32m (default) "
			echo -e "\033[0m"
		done

		while :
		do
			read -p 'Please enter your choice: ' choice
			len=`echo "$choice"|sed 's/[0-9]//g'|sed 's/-//g'`
			if [[ ! -n $len  && $choice -gt 0 && $choice -le ${#INET_IPS[@]} ]] ; then
				break
			fi
		done

		IPADDR=${INET_IPS[$choice-1]}

		# Configure the base image of pod
		KUBEADM_CONF=/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
		result=$(cat $KUBEADM_CONF | grep 'KUBELET_EXTRA_ARGS=')
		if [ -n result ] ; then
			KUBELET_EXTRA_ARGS="--fail-swap-on=false"
			sed -i "/Environment=\"KUBELET_CERTIFICATE_ARGS/a\Environment=\"KUBELET_EXTRA_ARGS=${KUBELET_EXTRA_ARGS}\"" $KUBEADM_CONF
		fi
		
		# It's neccesary to configre cgroup-driver=cgroupfs for installing docker 1.12.6
		# sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

		# Start components
		systemctl daemon-reload
		systemctl enable kubelet
		systemctl start kubelet

		# Create cluster
		kubeadm reset
		kubeadm init --apiserver-advertise-address=$IPADDR --kubernetes-version=v$KUBE_VERSION --pod-network-cidr=10.244.0.0/12 --ignore-preflight-errors 'Swap' | tee k8s_for_CentOS.log

		# Configure kubeconfig for kubectl
		mkdir -p $HOME/.kube
		[ -f $HOME/.kube/config ] && rm -rf $HOME/.kube/config
		cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
		chown $(id -u):$(id -g) $HOME/.kube/config

		# Check installation
		echo 'kubectl get cs...'
		kubectl get cs
		break
		;;
		2)
		echo << EOF
Usage: 
    kubeadm join --token [token] host:port --skip-preflight-checks
    kubectl get nodes
EOF
		break
		;;
		3)
		break
		;;
	esac
done

# Install flannel
echo "Do you want to install flannel?[Y/n]"
while :
do
	read -p 'Please Enter your choice: ' choice
	case $choice in 
		Y)
		docker pull $ALIYUN_URL/flannel-amd64:v$FLANNEL_VERSION
		docker tag $ALIYUN_URL/flannel-amd64:v$FLANNEL_VERSION quay.io/coreos/flannel:v$FLANNEL_VERSION-amd64
		docker rmi $ALIYUN_URL/flannel-amd64:v$FLANNEL_VERSION

		kubectl --namespace kube-system apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.0/Documentation/k8s-manifests/kube-flannel-rbac.yml
		wget https://raw.githubusercontent.com/coreos/flannel/v0.9.0/Documentation/kube-flannel.yml
		kubectl --namespace kube-system apply -f ./kube-flannel.yml
		rm -rf kube-flannel.yml
		break
		;;
		n)
		break
		;;
done

# Install ingress-nginx
echo "Do you want to install ingress-nginx?[Y/n]"
while :
do
	read -p 'Please Enter your choice: ' choice
	case $choice in 
		Y)
		docker pull $ALIYUN_URL/defaultbackend:$DEFAULT_BACKEND_VERSION
		docker tag $ALIYUN_URL/defaultbackend:$DEFAULT_BACKEND_VERSION gcr.io/google_containers/defaultbackend:$DEFAULT_BACKEND_VERSION
		docker rmi $ALIYUN_URL/defaultbackend:$DEFAULT_BACKEND_VERSION

		docker pull $ALIYUN_URL/nginx-ingress-controller:$NGINX_INGRESS_CONTROLLER_VERSION
		docker tag $ALIYUN_URL/nginx-ingress-controller:$NGINX_INGRESS_CONTROLLER_VERSION quay.io/kubernetes-ingress-controller/nginx-ingress-controller:$NGINX_INGRESS_CONTROLLER_VERSION
		docker rmi $ALIYUN_URL/nginx-ingress-controller:$NGINX_INGRESS_CONTROLLER_VERSION

		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/namespace.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/default-backend.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/configmap.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/tcp-services-configmap.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/udp-services-configmap.yaml
		
		echo 
		echo "Do you want to install rbac?[Y/n]"
		while :
		do
			read -p 'Please enter your choice: ' choice
			case $choice in
			Y) 
			kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/rbac.yaml
			kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/with-rbac.yaml
			break
			;;
			n) 
			kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/without-rbac.yaml
			break
			;;
			esac
		done
		break
		;;
		n) 
		break
		;;
done

# Install ingress dashboard
echo "Do you want to install ingress dashboard?[Y/n]"
while :
do
	read -p 'Please Enter your choice: ' choice
	case $choice in 
	Y)
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
	
	read -p 'Echo your host: ' HOST_NAME
	cat > dashboard-ingress.yaml << EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kube-system
spec:
  rules:
  - host: ${HOST_NAME}
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 80
EOF

	# Domain rewrite target
#	cat > dashboard-ingress.yaml << EOF
#apiVersion: extensions/v1beta1
#kind: Ingress
#metadata:
#  name: my-k8s-ingress
#  namespace: kube-system
#  annotations:
#    ingress.kubernetes.io/rewrite-target: /
#spec:
#  rules:
#  - host: ${HOST_NAME}
#    http:
#      paths:
#      - path: /dashboard
#        backend:
#          serviceName: kubernetes-dashboard
#          servicePort: 80
#EOF

	kubectl create -f dashboard-ingress.yaml
	rm -rf dashboard-ingress.yaml
	break
	;;
	n) 
	break
	;;
done
