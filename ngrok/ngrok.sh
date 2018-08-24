#!/bin/bash

yum -y install golang

mkdir -p /data/ngrok

wget https://github.com/inconshreveable/ngrok/archive/master.zip
unzip master.zip
rm -rf master.zip
mv ngrok-master ngrok2

mdir cert
cd cert
export NGROK_DOMAIN="ngrok.yourdomain.com"
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=$NGROK_DOMAIN" -out server.csr
openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 5000

cp rootCA.pem ../ngrok2/assets/client/tls/ngrokroot.crt
cp server.crt ../ngrok2/assets/server/tls/snakeoil.crt
cp server.key ../ngrok2/assets/server/tls/snakeoil.key

cd ../ngrok2
export GOPATH=/data/ngrok/ngrok2/

#win服务端
CGO_ENABLED=0 GOOS=windows GOARCH=386 make release-server 
#win客户端
CGO_ENABLED=0 GOOS=windows GOARCH=386 make release-client
#linux服务端
CGO_ENABLED=0 GOOS=linux GOARCH=386 make release-server
#linux客户端
CGO_ENABLED=0 GOOS=linux GOARCH=386 make release-client
#linux服务端
CGO_ENABLED=0 GOOS=darwin GOARCH=386 make release-server
#linux客户端
CGO_ENABLED=0 GOOS=darwin GOARCH=386 make release-client
#win服务端
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 make release-server 
#win客户端
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 make release-client
#linux服务端
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 make release-server
#linux客户端
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 make release-client
#linux服务端
CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 make release-server
#linux客户端
CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 make release-client
