#!/bin/bash

yes | kubeadm reset
rm -rf /etc/kubernetes
rm -rf $HOME/.kube
ifconfig cni0 down
ip link delete cni0
ifconfig flannel.1 down
ip link delete flannel.1
ip link delete dummy0
rm -rf /var/lib/cni/