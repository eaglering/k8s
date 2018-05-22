#!/bin/bash

if [[ ! -e /redis-data ]]; then
  echo "Redis master data doesn't exist, data won't be persistent!"
  mkdir /redis-data
fi

sed -i "s/%PORT%/${PORT}/" /etc/redis.conf
sed -i "s/%IPADDR%/${IPADDR}/" /etc/redis.conf

redis-server /etc/redis.conf --protected-mode no