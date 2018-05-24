#!/bin/bash

Install_Redis_Cluster() {
	IPADDR=$(hostname -i)
	mkdir -p $DATADIR/redis_6379 $DATADIR/redis_6380
	docker run --net=host --restart=always -d --name redis-cluster-1 -v $DATADIR/redis_6379:/redis-data \
	-e IPADDR="$IPADDR" \
	-e PORT="6379" \
	$ALIYUN_URL/redis:4.0.9
	docker run --net=host --restart=always -d --name redis-cluster-2 -v $DATADIR/redis_6380:/redis-data \
	-e IPADDR="$IPADDR" \
	-e PORT="6380" \
	$ALIYUN_URL/redis:4.0.9
	
	cat > $LOGDIR/docker-redis-cluster.log <<EOF
Execute the commands below:
	$ docker run -it --name=ruby --net=host ruby /bin/bash
	$ gem install redis \
	$ && wget http://download.redis.io/redis-stable/src/redis-trib.rb
	$ && ruby redis-trib.rb create --replicas 1 \
	$ ${IPADDR}:6379 <nodeN>:6379 ${IPADDR}:6380 <nodeN>:6
	
Finally, Do not forget to change your pass:
	$ docker exec redis-cluster-<ID> config set requirepass <your pass>
	$ docker exec redis-cluster-<ID> config set masterauth <your pass>
	$ docker exec redis-cluster-<ID> config rewrite

Other commands:
	$ ruby redis-trib.rb add-node <nodeN>:6379 <masterN>:6379
	$ ruby redis-trib.rb reshard <masterN>:6379
	$ ruby redis-trib.rb add-node --slave --master-id (masterId) <nodeN>:6380 <masterN>:6379
	$ ruby redis-trib.rb del-node <nodeN>:6379'
EOF
	cat $LOGDIR/docker-redis-cluster.log
}
