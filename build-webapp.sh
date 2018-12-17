#!/bin/bash

#常量配置
K8S_DIR=$HOME/k8s

mkdir -p $K8S_DIR/conf
mkdir -p $K8S_DIR/cert
mkdir -p $K8S_DIR/bin
mkdir -p $K8S_DIR/log

cat > $K8S_DIR/conf/secret-docker-registry.cmd <<EOF
docker login --username=xxx@qq.com registry.cn-shenzhen.aliyuncs.com
kubectl create secret docker-registry regcred --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
EOF

cat $K8S_DIR/conf/secret-docker-registry.cmd

read -p "Do you have done that already?\nPress Enter to continue.." answer

#创建web网站使用的pvc
cat > $K8S_DIR/conf/webapp-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim  
metadata:
  name: webapp-pvc
spec:
  storageClassName: "nfs"
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF
kubectl apply -f $K8S_DIR/conf/webapp-pvc.yaml

#php-fpm
cat > $K8S_DIR/conf/php72-fpm.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php72-fpm
spec:
  selector:
    matchLabels:
      app: php72-fpm
  template:
    metadata:
      labels:
        app: php72-fpm
    spec:
      containers:
      - name: php72-fpm
        image: registry-vpc.cn-shenzhen.aliyuncs.com/eaglering/php-fpm:latest
        ports:
        - containerPort: 9000
          protocol: TCP
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        persistentVolumeClaim:
          claimName: webapp-pvc
      imagePullSecrets:
      - name: regcred

---
apiVersion: v1
kind: Service
metadata:
  name: php72-fpm
spec:
  selector:
    app: php72-fpm
  ports:
  - name: php72-fpm
    protocol: TCP
    port: 9000
    targetPort: 9000
EOF
kubectl apply -f $K8S_DIR/conf/php72-fpm.yaml

#nginx
cat > $K8S_DIR/conf/nginx-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configmap
data:
  wing.conf: |
    server {
      listen       80;
      server_name  www.fastapi.com.cn fastapi.com.cn;
      root  /usr/share/nginx/web/wing/frontend/web;
      index index.php index.html index.htm;
      access_log  /var/log/nginx/wing_frontend_access.log;
      error_log  /var/log/nginx/wing_frontend_error.log;
      location / {
        try_files $uri $uri/ /index.php$args;
      }
	  location /api {
		rewrite ^/api/(.*)$ /api/index.php?$1 last;
	  }
      location ~ \.php$ {
        fastcgi_pass   php72-fpm:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
      }
      location ~ /\.(ht|svn|git) {
        deny all;
      }
    }
	
	server {
      listen       80;
      server_name  kf.fastapi.com.cn;
      root  /usr/share/nginx/web/wing/backend/web;
      index index.php index.html index.htm;
      access_log  /var/log/nginx/wing_backend_access.log;
      error_log  /var/log/nginx/wing_backend_error.log;
      location / {
        try_files $uri $uri/ /index.php$args;
      }
      location ~ \.php$ {
        fastcgi_pass   php72-fpm:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
      }
      location ~ /\.(ht|svn|git) {
        deny all;
      }
    }
EOF
kubectl apply -f $K8S_DIR/conf/nginx-configmap.yaml

cat > $K8S_DIR/conf/nginx.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          protocol: TCP
        volumeMounts:
        - name: confd
          mountPath: /etc/nginx/conf.d
        - name: web
          mountPath: /usr/share/nginx/web
      volumes:
      - name: confd
        configMap: 
          name: nginx-configmap
      - name: web
        persistentVolumeClaim:
          claimName: webapp-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  selector:
    app: nginx
  ports:
  - name: nginx
    protocol: TCP
    port: 80
    targetPort: 80
EOF
kubectl apply -f $K8S_DIR/nginx.yaml

#微服务
cat > $K8S_DIR/conf/wing-sandbox.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wing-sandbox
  labels:
    app: wing-sandbox
spec:
  replicas: 1
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: wing-sandbox
  template:
    metadata:
      labels:
        app: wing-sandbox
    spec:
      containers: 
      - name: wing-sandbox
        image: registry-vpc.cn-shenzhen.aliyuncs.com/eaglering/wing-sandbox:v2.0
        ports:
        - containerPort: 15746
          protocol: TCP
        - containerPort: 15747
          protocol: TCP
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
      imagePullSecrets:
      - name: regcred

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: wing-sandbox
  name: wing-sandbox
spec:
  selector:
    app: wing-sandbox
  ports:
  - name: wing-sandbox-grpc
    protocol: TCP
    port: 15746
    targetPort: 15746
  - name: wing-sandbox-http
    protocol: TCP
    port: 15747
    targetPort: 15747
EOF
kubectl apply -f $K8S_DIR/conf/wing-sandbox.yaml

#mysql endpoint
cat > $K8S_DIR/conf/mysql.yaml <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: mysql
  namespace: default
subsets:
- addresses:
  - ip: 172.18.211.159
  ports:
  - port: 3306

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
EOF
kubectl apply -f $K8S_DIR/conf/mysql.yaml

cat > $K8S_DIR/conf/redis.yaml <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: redis
  namespace: default
subsets:
- addresses:
  - ip: 172.18.211.159
  ports:
  - port: 6379

---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  ports:
  - port: 6379
EOF
kubectl apply -f $K8S_DIR/conf/redis.yaml