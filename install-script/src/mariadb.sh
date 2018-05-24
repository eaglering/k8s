#!/bin/bash

Install_Mariadb() {
	IPADDR=$(hostname -i)
	mkdir -p $ROOTDIR/externel
	wget -O $ROOTDIR/externel/oneinstack-full.tar.gz http://mirrors.linuxeye.com/oneinstack-full.tar.gz
	tar xzf $ROOTDIR/externel/oneinstack-full.tar.gz -C $ROOTDIR/externel
	while :
	do
		read -p "Enter password for mysql: " $PASSWORD
		read -p "Re password: " $REPASSWORD
		if {[ -n $PASSWORD ] && [ $PASSWORD == $REPASSWORD ]]; then
			break
		fi
	done
	$ROOTDIR/externel/oneinstack/install.sh --db_option 5 --dbinstallmethod 1 --dbrootpwd $PASSWORD
	
	while :
	do
		read -p "Auto increment offset: " OFFSET
		if [ -z `FUNC_IS_INT $OFFSET` ]; then
			break
		fi
	done
	if [ -z "`cat /etc/my.cnf | grep '# Add 3 rows'`" ]; then
		sed -i "s/server-id = 1/server-id = ${OFFSET}" /etc/my.cnf
		sed -i "/expire_logs_days/a# Add 3 rows\nlog_slave_updates\nauto_increment_increment = 10\nauto_increment_offset = ${OFFSET}" /etc/my.cnf
	fi
	
	service mysqld restart
	
	ln -s /usr/local/mariadb/bin/mysql /usr/local/bin/mysql
	
	cat << EOF
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'${HOSTNAME}' IDENTIFIED BY '????'
FLUSH PRIVILEGES;
SHOW MASTER STATUS;
CHANGE MASTER TO MASTER_HOST='???', MASTER_PORT=3306, MASTER_PASSWORD='???', MASTER_LOG_FILE='mysql-bin.???', MASTER_LOG_POS=???;
START SLAVE;
EOF
}