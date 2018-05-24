#!/bin/bash

Install_Ingress_Nginx() {
	wget -O $CONFDIR/kube-ingress-nginx-namespace.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/namespace.yaml
	wget -O $CONFDIR/kube-ingress-nginx-default-backend.yaml https://raw.githubusercontent.com/eaglering/k8s/v1.10.2/nginx-ingress-controller/default-backend.yaml
	wget -O $CONFDIR/kube-ingress-nginx-configmap.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/configmap.yaml
	wget -O $CONFDIR/kube-ingress-nginx-tcp-services-configmap.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/tcp-services-configmap.yaml
	wget -O $CONFDIR/kube-ingress-nginx-udp-services-configmap.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/udp-services-configmap.yaml
	
	kubectl apply -f $CONFDIR/kube-ingress-nginx-namespace.yaml
	kubectl apply -f $CONFDIR/kube-ingress-nginx-default-backend.yaml
	kubectl apply -f $CONFDIR/kube-ingress-nginx-configmap.yaml
	kubectl apply -f $CONFDIR/kube-ingress-nginx-tcp-services-configmap.yaml
	kubectl apply -f $CONFDIR/kube-ingress-nginx-udp-services-configmap.yaml

	while :
	do
		read -p 'Install RBAC roles for ingress nginx: [Y/n]' choice
		case $choice in
			Y) 
			wget -O $CONFDIR/kube-ingress-nginx-rbac.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/rbac.yaml
			wget -O $CONFDIR/kube-ingress-nginx-with-rbac.yaml https://raw.githubusercontent.com/eaglering/k8s/v1.10.2/nginx-ingress-controller/with-rbac.yaml
			kubectl apply -f $CONFDIR/kube-ingress-nginx-rbac.yaml
			kubectl apply -f $CONFDIR/kube-ingress-nginx-with-rbac.yaml
			
			cat > $BINDIR/admin-user.sh << EOF
#!/bin/bash
kubectl describe secret \$(kubectl describe serviceaccount admin-user -n kube-system | grep Tokens | awk '{print \$2}') -n kube-system		
EOF
			chmod 755 $BINDIR/admin-user.sh
			echo "\$ ${BINDIR}/admin-user.sh # To capute token value."
			break
			;;
			n) 
			wget -O $CONFDIR/kube-ingress-nginx-without-rbac.yaml https://raw.githubusercontent.com/eaglering/k8s/v1.10.2/nginx-ingress-controller/without-rbac.yaml
			kubectl apply -f $CONFDIR/kube-ingress-nginx-without-rbac.yaml
			break
			;;
		esac
	done
}

Install_Ingress_Dashboard() {
	wget -O $CONFDIR/kube-ingress-nginx-dashboard.yaml https://raw.githubusercontent.com/eaglering/k8s/v1.10.2/dashboard-amd64/kubernetes-dashboard.yaml
	kubectl apply -f $CONFDIR/kube-ingress-nginx-dashboard.yaml

	cat > $CONFDIR/kube-ingress-nginx-tls-ingress.yaml <<EOF
mkdir pki
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout pki/tls.key -out pki/tls.crt -subj "/CN=http://DOMAIN/O=http://DOMAIN"
kubectl create secret tls ingress-tls --key pki/tls.key --cert pki/tls.crt -n kube-system
EOF
	cat $CONFDIR/kube-ingress-nginx-tls-ingress.yaml
	
	cat > $CONFDIR/kube-ingress-nginx-ing.yaml <<EOF
# -------------- Dashboard Ingress -------------#
#kind: ConfigMap
#apiVersion: v1
#metadata:
#  name: nginx-config
#data:
#  ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA"
#  ssl-protocols: "TLSv1 TLSv1.1 TLSv1.2"
#  
#---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kube-system
  annotations:
    nginx.ingress.kubernetes.io/secure-backends: "true"
spec:
#  tls:
#  - hosts:
# 	 - dashboard.fastapi.com.cn
#    secretName: ingress-tls
#  - hosts:
# 	 - www.fastapi.com.cn
#    secretName: ingress-tls-1
  rules:
  - host: dashboard.fastapi.com.cn
    http:
      paths:
	  - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
EOF
	cat $CONFDIR/kube-ingress-nginx-ing.yaml
	
	cat <<EOF
/** 
 * Edit and apply the tls-ingress.yaml only if you want to use https protocol
 * This script make secret for tls. eg:
 * kubectl apply -f $CONFDIR/kube-ingress-nginx-tls-ingress.yaml
 * uncomment spec.tls in $CONFDIR/kube-ingress-nginx-dashboard-ingress.yaml
 */
$ kubectl apply -f $CONFDIR/kube-ingress-nginx-dashboard-ingress.yaml

# Updating an Ingress
$ kubectl get ing
NAME      RULE          BACKEND   ADDRESS
test      -                       178.91.123.132
          foo.bar.com
          /foo          s1:80
$ kubectl edit ing test
EOF
}
