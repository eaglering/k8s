#!/bin/bash

#前置工作
echo <<EOF
echo 172.18.211.157 k8s-node2 >> /etc/hosts
hostnamectl set-hostname k8s-node2
EOF

read -p "Do you have done that already?\nPress Enter to continue.." answer

KUBERNETES_VERSION=1.13.0
DOCKER_VERSION=18.06.1.ce

PAUSE_VERSION=3.1
ETCD_VERSION=3.2.24
COREDNS_VERSION=1.2.6
DEFAULTBACKEND_VERSION=1.4

#系统配置
systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

swapoff -a
yes | cp /etc/fstab /etc/fstab_bak
cat /etc/fstab_bak |grep -v swap > /etc/fstab

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF

modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf

yum -y install nfs-utils

#kube-proxy开启ipvs的前置条件
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
yum -y install ipset ipvsadm

#安装Docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo	
yum makecache fast
yum install -y --setopt=obsoletes=0 \
  docker-ce-${DOCKER_VERSION}
systemctl start docker
systemctl enable docker

#安装Kubernetes源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum -y install kubelet-${KUBERNETES_VERSION} kubeadm-${KUBERNETES_VERSION} kubectl-${KUBERNETES_VERSION}
systemctl enable kubelet.service

#下载离线镜像
images=(mirrorgooglecontainers/kube-apiserver-amd64:v${KUBERNETES_VERSION}
mirrorgooglecontainers/kube-controller-manager-amd64:v${KUBERNETES_VERSION}
mirrorgooglecontainers/kube-scheduler-amd64:v${KUBERNETES_VERSION}
mirrorgooglecontainers/kube-proxy-amd64:v${KUBERNETES_VERSION}
mirrorgooglecontainers/pause:${PAUSE_VERSION}
mirrorgooglecontainers/etcd-amd64:${ETCD_VERSION}
mirrorgooglecontainers/defaultbackend:${DEFAULTBACKEND_VERSION}
coredns/coredns:${COREDNS_VERSION})

for image in ${images[@]} ; do
  docker pull $image
  imageName=$(echo "${image}" | awk -F/ '{print $2}' | sed 's/-amd64//g')
  docker tag $image k8s.gcr.io/$imageName
  docker rmi $image
done

#加入kubernetes集群
Enjoy!





	
	