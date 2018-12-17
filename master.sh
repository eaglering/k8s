#!/bin/bash

#前置工作
echo <<EOF
echo 172.18.211.159 k8s-node1 >> /etc/hosts
hostnamectl set-hostname k8s-node1
EOF

read -p "Do you have done that already?\nPress Enter to continue.." answer

#常量配置
K8S_DIR=$HOME/k8s

mkdir -p $K8S_DIR/conf
mkdir -p $K8S_DIR/cert
mkdir -p $K8S_DIR/bin
mkdir -p $K8S_DIR/log

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

#安装kubernetes环境
kubeadm init --kubernetes-version=v${KUBERNETES_VERSION} --pod-network-cidr=10.244.0.0/16 > $K8S_DIR/log/kubeadm-init.log

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#安装网络
wget -O $K8S_DIR/conf/kube-network-addon-flannel.yaml https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f $K8S_DIR/conf/kube-network-addon-flannel.yaml

#允许master做为工作负载
read -p "Enable master scheduling?[y/N]" answer
if [ $answer = 'y' || $anser = 'Y' || $answer = 'Yes' || $answer = 'yes' ]; then
    kubectl taint nodes k8s-node1 node-role.kubernetes.io/master-
fi

#开启ivps模式
read -p "Enable IPVS mode? Modify config.conf, mode: "ipvs"[y/N]" answer
if [ $answer = 'y' || $anser = 'Y' || $answer = 'Yes' || $answer = 'yes' ]; then
    kubectl edit cm kube-proxy -n kube-system
	kubectl get pod -n kube-system | grep kube-proxy | awk '{system("kubectl delete pod "$1" -n kube-system")}'
	kubectl logs kube-proxy-pf55q -n kube-system
fi

#安装helm和tiller
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.0-linux-amd64.tar.gz
tar -zxvf helm-v2.12.0-linux-amd64.tar.gz
cd linux-amd64/
cp helm /usr/local/bin/
cat > $K8S_DIR/conf/tiller-rbac-config.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
kubectl create -f $K8S_DIR/conf/tiller-rbac-config.yaml
helm init --service-account tiller --skip-refresh --upgrade -i registry.cn-shenzhen.aliyuncs.com/cnrancher/tiller:v2.12.0
helm repo update

#安装ingress-nginx
kubectl label node k8s-node1 node-role.kubernetes.io/edge=
cat > $K8S_DIR/conf/ingress-nginx.yaml <<EOF
controller:
  replicaCount: 1
  hostNetwork: true
  nodeSelector:
    node-role.kubernetes.io/edge: ''
  tolerations:
    - key: node-role.kubernetes.io/master
      operator: Exists
      effect: NoSchedule

defaultBackend:
  nodeSelector:
    node-role.kubernetes.io/edge: ''
  tolerations:
    - key: node-role.kubernetes.io/master
      operator: Exists
      effect: NoSchedule
EOF
helm install stable/nginx-ingress -n nginx-ingress --namespace ingress-nginx  -f $K8S_DIR/conf/nginx-ingress.yaml > $K8S_DIR/log/nginx-ingress.log

#分配PV
cat > $K8S_DIR/conf/pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-nfs-server-provisioner-0
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/volumes/data-nfs-server-provisioner-0
  claimRef:
    namespace: kube-system
    name: data-nfs-server-provisioner-0
EOF
kubectl apply -f $K8S_DIR/conf/pv.yaml

#安装nfs-server
cat > $K8S_DIR/conf/nfs-server-provisioner.yaml <<EOF
persistence:
  enabled: true
  storageClass: "-"
  size: 10Gi
  
storageClass:
  defaultClass: true
  
nodeSelector:
  kubernetes.io/hostname: k8s-node1
EOF
helm install stable/nfs-server-provisioner -n nfs-server-provisioner --namespace kube-system -f $K8S_DIR/conf/nfs-server-provisioner.yaml > $K8S_DIR/log/nfs-server-provisioner.log

kubectl get pods --all-namespaces
echo On slave:
cat $K8S_DIR/log/kubeadm-init.log | grep 'kubeadm join'





	
	