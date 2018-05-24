#!/bin/bash

Init_Etcd() {
	mkdir -p $CERTDIR/etcd
	IPADDR=$(hostname -i)
}

Install_Etcd() {
	while :
	do
		read -p "Use TLS for etcd[Y/n]?" ETCD_USE_HTTPS
		case $ETCD_USE_HTTPS in 
		Y)
			echo "cp kubernetes.config.tls.sample kubernetes.config, then modify it to support TLS."
			read -p "Check ${CERTDIR}/etcd/, has all the pem. It right[ok]?" choice
			if [ -z $DISCOVERY ]; then
				docker run -d --net=host --restart always -v $CERTDIR/etcd:/cert \
					--name etcd quay.io/coreos/etcd:v$ETCD_VERSION \
					/usr/local/bin/etcd \
					--name $HOSTNAME-etcd \
					--initial-advertise-peer-urls https://$IPADDR:2380 \
					--listen-peer-urls https://$IPADDR:2380 \
					--advertise-client-urls https://$IPADDR:2379 \
					--listen-client-urls https://$IPADDR:2379,https://127.0.0.1:2379 \
					--initial-cluster-state new \
					--initial-cluster-token etcd-cluster \
					--cert-file=/cert/server.pem \
					--key-file=/cert/server-key.pem \
					--peer-cert-file=/cert/server.pem \
					--peer-key-file=/cert/server-key.pem \
					--trusted-ca-file=/cert/ca.pem \
					--peer-trusted-ca-file=/cert/ca.pem
			else
				docker run -d --net=host --restart=always -v $CERTDIR/etcd:/cert \
					--name etcd quay.io/coreos/etcd:v$ETCD_VERSION \
					/usr/local/bin/etcd \
					--name $HOSTNAME-etcd \
					--initial-advertise-peer-urls https://$IPADDR:2380 \
					--listen-peer-urls https://$IPADDR:2380 \
					--advertise-client-urls https://$IPADDR:2379 \
					--listen-client-urls https://$IPADDR:2379,https://127.0.0.1:2379 \
					--initial-cluster-state new \
					--initial-cluster-token etcd-cluster \
					--discovery $DISCOVERY \
					--cert-file=/cert/server.pem \
					--key-file=/cert/server-key.pem \
					--peer-cert-file=/cert/server.pem \
					--peer-key-file=/cert/server-key.pem \
					--trusted-ca-file=/cert/ca.pem \
					--peer-trusted-ca-file=/cert/ca.pem			
			fi
			break
		;;
		n)
			if [ -z $DISCOVERY ]; then
				docker run -d --net=host --restart=always --name etcd quay.io/coreos/etcd:v$ETCD_VERSION \
					/usr/local/bin/etcd \
					--name $HOSTNAME-etcd \
					--initial-advertise-peer-urls http://$IPADDR:2380 \
					--listen-peer-urls http://$IPADDR:2380 \
					--advertise-client-urls http://$IPADDR:2379 \
					--listen-client-urls http://$IPADDR:2379,http://127.0.0.1:2379 \
					--initial-cluster-state new \
					--initial-cluster-token etcd-cluster
			else
				docker run -d --net=host --restart=always --name etcd quay.io/coreos/etcd:v$ETCD_VERSION \
					/usr/local/bin/etcd \
					--name $HOSTNAME-etcd \
					--initial-advertise-peer-urls http://$IPADDR:2380 \
					--listen-peer-urls http://$IPADDR:2380 \
					--advertise-client-urls http://$IPADDR:2379 \
					--listen-client-urls http://$IPADDR:2379,http://127.0.0.1:2379 \
					--initial-cluster-state new \
					--initial-cluster-token etcd-cluster \
					--discovery $DISCOVERY
			fi
			break
		;;
		esac
	done

	docker exec etcd sh -c "apk update && apk add ca-certificates"
	docker restart etcd
}

Install_Etcd_Master() {
	Init_Etcd
	while :
	do
		read -p "Size of etcd[default 0(manual)]: " SIZE
		if [ -z $SIZE ]; then
			SIZE=0
			break
		elif [ -z `FUNC_IS_INT $SIZE` ]; then
			break
		fi
	done
	
	if [ $SIZE != 0 ]; then
		DISCOVERY=$(curl https://discovery.etcd.io/new?size=$SIZE)
		cat > $LOGDIR/etcd.log <<EOF
/************************************************************
 ** Discovry Address(Important): $DISCOVERY
************************************************************/
EOF
		cat $LOGDIR/etcd.log
	else
		DISCOVERY=""
	fi
	Install_Etcd
}

Install_Etcd_Slave() {
	Init_Etcd
	read -p "Discovery Address[default manual)]: " DISCOVERY
	Install_Etcd
}
