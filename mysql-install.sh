#!/bin/bash

### Describe: MySQL auto install script for version: 5.6, 5.7, 8.0...
### Author: liaobaikai<baikai.liao@qq.com>
### Script version: 1.2.0
### Create time: 2021-01-01
### Update time: 2021-01-14
### Required Command: ip, wget, apt-get/yum/dnf

# Download url
# https://dev.mysql.com/downloads/mysql/
# https://downloads.mysql.com/archives/community/



current_simple_date=`date "+%Y%m%d%H%M%S"`

# https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.21-linux-glibc2.12-x86_64.tar.xz
MYSQL_DOWNLOAD_URL=""
MYSQL_INSTALL_FILE=""

SERVER_ID=1001
CHARSET=utf8mb4
PORT=3308
DEFAULT_PASSWORD=root
SERVICE_NAME=mysql8d.service

INSTALL_DIR=/usr/local
MYSQL_HOME=$INSTALL_DIR/mysql8
MYSQL_CONFIG_DIR=/etc/mysql8
MYSQL_DATA_BASE_DIR=/data/mysql8
MYSQL_DATA_DIR=$MYSQL_DATA_BASE_DIR/data
MYSQL_LOG_DIR=$MYSQL_DATA_BASE_DIR/logs
MYSQL_INSTALL_LOG_FILE=/var/log/mysql-${mysql_version}-${current_simple_date}-install.log


LOG_LEVEL_INFO="INFO"
LOG_LEVEL_WARNING="WARNING"
LOG_LEVEL_FATAL="FATAL"

logger(){
        current_date=`date "+%Y-%m-%d %H:%M:%S"`
        level=$2
        if [ "$level" == "" ]; then
                level=$LOG_LEVEL_INFO
        fi
        echo "$current_date - [$level]: $1" >> ${MYSQL_INSTALL_LOG_FILE}
        echo "$current_date - [$level]: $1"
}

for arg in "$@"
do
	value=`echo "$arg" | sed -e 's/^[^=]*=//'`
        case "$arg" in 
        	--install-dir=*) INSTALL_DIR=$value ;;
                --server-id=*) SERVER_ID=$value ;;
                --charset=*) CHARSET=$value ;;
                --port=*) PORT=$value ;;
                --password=*) DEFAULT_PASSWORD=$value ;;
                --service-name=*) SERVICE_NAME=$value ;;
                --download-url=*) MYSQL_DOWNLOAD_URL=$value ;;
                --install-file=*) MYSQL_INSTALL_FILE=$value ;;
                --home=*) MYSQL_HOME=$value ;;
                --config-dir=*) MYSQL_CONFIG_DIR=$value ;;
                --data-dir=*) MYSQL_DATA_DIR=$value ;;
                --log-dir=*) MYSQL_LOG_DIR=$value ;;
                --install-log-file=*) MYSQL_INSTALL_LOG_FILE=$value ;;
        esac  
done    

logger "INSTALL_DIR=$INSTALL_DIR"
logger "SERVER_ID=$SERVER_ID"
logger "CHARSET=$CHARSET"
logger "PORT=$PORT"
logger "DEFAULT_PASSWORD=$DEFAULT_PASSWORD"
logger "SERVICE_NAME=$SERVICE_NAME"
logger "MYSQL_DOWNLOAD_URL=$MYSQL_DOWNLOAD_URL"
logger "MYSQL_INSTALL_FILE=$MYSQL_INSTALL_FILE"
logger "MYSQL_HOME=$MYSQL_HOME"
logger "MYSQL_CONFIG_DIR=$MYSQL_CONFIG_DIR"
logger "MYSQL_DATA_DIR=$MYSQL_DATA_DIR"
logger "MYSQL_LOG_DIR=$MYSQL_LOG_DIR"
logger "MYSQL_INSTALL_LOG_FILE=$MYSQL_INSTALL_LOG_FILE"


download_mysql_install_file(){
        cd $INSTALL_DIR
	if [ ! -f $mysql_install_file ]; then
                logger "Downloading $mysql_install_file to $INSTALL_DIR..."
                if ! type wget > /dev/null 2>&1; then 
                        install_package "wget"
                fi
		wget $MYSQL_DOWNLOAD_URL
	fi
}

if [ "$MYSQL_DOWNLOAD_URL" != "" ]; then
        mysql_install_file=$(basename $MYSQL_DOWNLOAD_URL)
        # download file
        download_mysql_install_file
else
        mysql_install_file=$MYSQL_INSTALL_FILE
        if [[ "$mysql_install_file" =~ ^/.* ]]; then
                echo "" >> /dev/null
        else
                mysql_install_file=$INSTALL_DIR/$mysql_install_file
        fi
fi


# get mysql version from filename
if [[ $mysql_install_file =~ '5.6' ]]; then
	mysql_version="5.6"
elif [[ $mysql_install_file =~ '5.7' ]]; then
	mysql_version="5.7"
elif [[ $mysql_install_file =~ '8.0' ]]; then
	mysql_version="8.0"
fi
logger "MySQL Version: $mysql_version"


linux_release_version=$(cat /proc/version | awk -F '(' '{print $4}' | sed 's/).*//')
linux_version=$(echo $linux_release_version | sed -e 's/[^0-9.-]*//g')
linux=$(echo $linux_release_version | sed -e 's/[0-9.-]*//g' -e 's/[[:space:]]//g')

# echo "Linux: $linux"
# echo "Linux version: $linux_version"
echo "Linux release version: $linux_release_version"

# case $linux in
# 	RedHat)
# 		echo "RedHat"		
# 		;;
# 	Alpine)
# 		echo "Alpine"
# 		;;
# esac	


install_package(){
        package_name=$1

        if type apt-get > /dev/null 2>&1; then
                CMD=apt-get
        elif type dnf > /dev/null 2>&1; then
                CMD=dnf
        elif type yum > /dev/null 2>&1; then
                CMD=yum
        fi

        if [ "$package_name" == "" ]; then
                return
        fi

        logger "Checking package ${package_name}..."
        $CMD install -y $package_name 2> /dev/null
        logger "Done."

}


# https://dev.mysql.com/doc/refman/5.7/en/binary-installation.html
preinstall(){

        install_package "libaio*"
        install_package "numactl*"
        install_package "libssl*"
        install_package "openssl*"

        if [[ $linux_version =~ ^8.* ]]; then
                logger "Checking package ncurses-compat-libs..."
                dnf install -y ncurses-compat-libs > /dev/null
                logger "Done."
        fi

	#echo "Checking command 'ip' ... "
	#if type ip > /dev/null 2>&1; then
	#	echo "OK."
	#else
	#	echo "Command 'ip' not exists!!! Script exit."
	#	exit 0
	#fi

	# ip=$(ip addr | grep -E `netstat -nr | grep '^0.0.0.0' | awk '{print $8}' | sed ":a;N;s/\n/|/g;ta"` | grep '/' | awk '{print $2}' | awk -F '/' '{print $1}')
	# echo "Get localhost ip: $ip"
	# echo $ip | awk -F '.' '{print $NF}'
	# install_count=$(cat /var/log/mysql-${mysql_version}-install.log)
	
	# user & group
	has_group=$(cat /etc/group | grep mysql | wc -l)
	if [ $has_group -eq 0 ]; then 
		groupadd mysql
                logger "group mysql created."
        else
                logger "Skip: group mysql exists."
	fi
	has_user=$(cat /etc/passwd | grep mysql | wc -l)
	if [ $has_user -eq 0 ]; then 
		useradd -r -g mysql -s /bin/false mysql
                logger "user mysql created."
        else
                logger "Skip: user mysql exists."
	fi

}

preinstall_system(){
	# /etc/selinux/config
        SELINUX=/etc/selinux/config
        LIMITS=/etc/security/limits.conf
        SYSCTL=/etc/sysctl.conf

        if [ -f $SELINUX ]; then
                sed -i 's/^SELINUX=.*$/SELINUX=disabled/' $SELINUX 1 2> /dev/null
                logger "Change $SELINUX SELINUX=disabled..."
        else
                logger "Skip: $SELINUX not exists!"
        fi

	# /etc/security/limits.conf
        if [ -f $LIMITS ]; then
	        is_add_ulimit=$(grep '^mysql' $LIMITS | wc -l)
                if [ $is_add_ulimit -ne 8 ]; then 
                        cat >> $LIMITS <<- EOF

mysql   soft    nofile   1024   
mysql   hard    nofile   65536   
mysql   soft    nproc    16384   
mysql   hard    nproc    16384   
mysql   soft    stack    10240   
mysql   hard    stack    32768  
mysql   hard    memlock  134217728  
mysql   soft    memlock  134217728  

EOF
                        logger "Change $LIMITS ulimit..."
	        fi
        else
               logger "Skip: $LIMITS not exists!" 
        fi
	
        if [ -f $SYSCTL ]; then
                sed -i '/fs.file-max/d' $SYSCTL && echo "fs.file-max = 6815744" >> $SYSCTL && sysctl -p 1 2> /dev/null
                logger "Change $SYSCTL fs.file-max=6815744..."
        else
              logger "Skip: $SYSCTL not exists!"   
        fi
}


preinstall_mysql_conf(){

	if [ ! -d ${MYSQL_CONFIG_DIR} ]; then
		mkdir -p ${MYSQL_CONFIG_DIR}
                logger "${MYSQL_CONFIG_DIR} created."
	fi

	cat >> ${MYSQL_CONFIG_DIR}/my.cnf <<- EOF
!includedir ${MYSQL_CONFIG_DIR}/conf.d/
!includedir ${MYSQL_CONFIG_DIR}/mysql.conf.d/
EOF
        logger "${MYSQL_CONFIG_DIR}/my.cnf created."

	mkdir -p ${MYSQL_CONFIG_DIR}/conf.d/
        logger "${MYSQL_CONFIG_DIR}/conf.d/ created."
	mkdir -p ${MYSQL_CONFIG_DIR}/mysql.conf.d/
        logger "${MYSQL_CONFIG_DIR}/mysql.conf.d/ created."

	cat >> ${MYSQL_CONFIG_DIR}/conf.d/mysqldump.cnf <<- EOF
[mysqldump]
quick
quote-names
max_allowed_packet	= 16M
EOF
        logger "${MYSQL_CONFIG_DIR}/conf.d/mysqldump.cnf created."

	cat >> ${MYSQL_CONFIG_DIR}/conf.d/mysql.cnf <<- EOF
[mysql]
socket		        =       $MYSQL_DATA_DIR/mysqld.sock
EOF
        logger "${MYSQL_CONFIG_DIR}/conf.d/mysql.cnf created."


        MYSQLD_CONFIG=${MYSQL_CONFIG_DIR}/mysql.conf.d/mysqld.cnf

	cat >> $MYSQLD_CONFIG <<- EOF
[mysqld]
port                    =       $PORT
pid-file	        =       $MYSQL_DATA_DIR/mysqld.pid
socket		        =       $MYSQL_DATA_DIR/mysqld.sock
datadir		        =       $MYSQL_DATA_DIR
symbolic-links          =       0

# log 
log-error               =       $MYSQL_DATA_DIR/error.log

# innodb
innodb_buffer_pool_size =       100M
innodb_log_buffer_size  =       8M
innodb_log_file_size    =       100M
innodb_flush_method     =       O_DIRECT

query_cache_type        =       0
query_cache_size        =       0

innodb_file_per_table   =       ON

open_files_limit        =       65535
key_buffer_size         =       32M

table_open_cache        =       400
table_definition_cache  =       400
innodb_flush_log_at_trx_commit = 1
sync_binlog             =       1

innodb_doublewrite      =       1

# binlog
relay_log               =       $MYSQL_LOG_DIR/mysql-relay-bin
log_bin                 =       $MYSQL_LOG_DIR/mysql-bin
binlog_format           =       ROW
max_binlog_size         =       100M
log_slave_updates       =       1


character_set_server    =       $CHARSET 

server_id               =       $SERVER_ID

gtid_mode               =       on
enforce_gtid_consistency=       1

relay_log_recovery      =       ON

# semi sync
# plugin_load             =       "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
# rpl_semi_sync_master_enabled = 1
# rpl_semi_sync_master_timeout = 3000
# rpl_semi_sync_master_wait_no_slave = ON
# rpl_semi_sync_master_wait_point = AFTER_SYNC
# rpl_semi_sync_master_wait_for_slave_count = 1

#rpl_semi_sync_slave_enabled = 1

skip-name-resolve

tx_isolation            = 'READ COMMITTED'

EOF
        logger "$MYSQLD_CONFIG created."

        # delete unknown variable for version 8.0
        if [ $mysql_version == '8.0' ]; then
                sed -i '/symbolic-links/d' $MYSQLD_CONFIG
                sed -i '/query_cache_/d' $MYSQLD_CONFIG
	fi

	logger "!!!!! default parameter: innodb_buffer_pool_size = 100M !!!!!" $LOG_LEVEL_WARNING
	
}

install_mysql8(){
        logger "$MYSQL_HOME/bin/mysqld --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log --initialize"
        $MYSQL_HOME/bin/mysqld --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log --initialize
        logger "$MYSQL_HOME/bin/mysql_ssl_rsa_setup --datadir=$MYSQL_DATA_DIR"
        $MYSQL_HOME/bin/mysql_ssl_rsa_setup --datadir=$MYSQL_DATA_DIR

        # update $MYSQL_HOME/support-files/mysql.server 
        logger "Updating $MYSQL_HOME/support-files/mysql.server datadir, basedir..."
        sed -i "s/^datadir=.*$/datadir=${MYSQL_DATA_DIR//\//\\\/}/" $MYSQL_HOME/support-files/mysql.server 
        sed -i "s/^basedir=.*$/basedir=${MYSQL_HOME//\//\\\/}/" $MYSQL_HOME/support-files/mysql.server 
        logger "Done."
}

install_mysql7(){
        logger "$MYSQL_HOME/bin/mysqld --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log --initialize"
        $MYSQL_HOME/bin/mysqld --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log --initialize
        logger "$MYSQL_HOME/bin/mysql_ssl_rsa_setup"
        $MYSQL_HOME/bin/mysql_ssl_rsa_setup

        # update $MYSQL_HOME/support-files/mysql.server 
        logger "Updating $MYSQL_HOME/support-files/mysql.server datadir, basedir..."
        sed -i "s/^datadir=.*$/datadir=${MYSQL_DATA_DIR//\//\\\/}/" $MYSQL_HOME/support-files/mysql.server 
        sed -i "s/^basedir=.*$/basedir=${MYSQL_HOME//\//\\\/}/" $MYSQL_HOME/support-files/mysql.server 
        logger "Done."
}

install_mysql6(){
        logger "$MYSQL_HOME/scripts/mysql_install_db --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log"
        $MYSQL_HOME/scripts/mysql_install_db --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql --log-error=$MYSQL_DATA_DIR/error.log
        logger "$MYSQL_HOME/bin/mysqld_safe --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql &"
        $MYSQL_HOME/bin/mysqld_safe --defaults-file=${MYSQL_CONFIG_DIR}/my.cnf --user=mysql &
        logger "cp $MYSQL_HOME/support-files/mysql.server /etc/init.d/${SERVICE_NAME}"
        cp $MYSQL_HOME/support-files/mysql.server /etc/init.d/${SERVICE_NAME}
}

add_service(){
        SERVICE_FILE=/usr/lib/systemd/system/${SERVICE_NAME}

        cat > $SERVICE_FILE <<- EOF
[Unit]

Description=MySQL Server
After=network.target
After=syslog.target

[Service]

User=mysql
Group=mysql
Type=forking

PermissionsStartOnly=true

ExecStart=$MYSQL_HOME/support-files/mysql.server start
ExecStop=$MYSQL_HOME/support-files/mysql.server stop
ExecReload=$MYSQL_HOME/support-files/mysql.server restart

LimitNOFILE = 5000
[Install]
WantedBy=multi-user.target

EOF
        chmod 644 $SERVICE_FILE
        logger "$SERVICE_FILE created."

}

install(){
	
        if [ -d $MYSQL_DATA_DIR ]; then
                if [ `ls $MYSQL_DATA_DIR | wc -l` -ne 0 ]; then
                        logger "Mysql data directory: $MYSQL_DATA_DIR is not empty!" $LOG_LEVEL_FATAL
		        exit 0
                fi
        fi

        # https://dev.mysql.com/doc/refman/5.6/en/binary-installation.html
        # https://dev.mysql.com/doc/refman/5.7/en/binary-installation.html
	mysql_install_file_dir=$(echo $mysql_install_file | sed 's/.tar.*//')
	if [ ! -d $mysql_install_file_dir ]; then
                suffix=$(echo $mysql_install_file | awk -F '.' '{print $NF}')
                case $suffix in
                        gz)
                                logger "Starting: tar -zxf $mysql_install_file ... "
                                tar -zxf $mysql_install_file -C $INSTALL_DIR
                                logger "done."
                                ;;
                        xz)
                                logger "Starting: tar -xf $mysql_install_file ... "
                                tar -xf $mysql_install_file -C $INSTALL_DIR
                                logger "done."
                                ;;
                        tar)
                                logger "Starting: tar -xf $mysql_install_file ... "
                                tar -xf $mysql_install_file -C $INSTALL_DIR
                                logger "done."
                                ;;
                        #...
                esac
	fi

        if [ ! -d $MYSQL_HOME ]; then
                if [ ! -d $mysql_install_file_dir ]
                then
                        logger "$mysql_install_file_dir is not directory!!!" $LOG_LEVEL_FATAL
                        exit 0
                fi
                ln -s $mysql_install_file_dir $MYSQL_HOME
                logger "ln -s $mysql_install_file_dir $MYSQL_HOME"
        fi

        preinstall_mysql_conf

	mkdir -p $MYSQL_DATA_DIR $MYSQL_LOG_DIR
        logger "mkdir -p $MYSQL_DATA_DIR $MYSQL_LOG_DIR"

	chown mysql:mysql $MYSQL_DATA_DIR $MYSQL_LOG_DIR
        logger "chown mysql:mysql $MYSQL_DATA_DIR $MYSQL_LOG_DIR"

	chmod 750 $MYSQL_DATA_DIR $MYSQL_LOG_DIR
        logger "chmod 750 $MYSQL_DATA_DIR $MYSQL_LOG_DIR"

        cat > ${MYSQL_HOME}/my.cnf <<- EOF
!include ${MYSQL_CONFIG_DIR}/my.cnf
EOF
        logger "$MYSQL_HOME/my.cnf created."

        logger "Starting install mysql...version: $mysql_version"

	if [ $mysql_version == '5.6' ]; then
                install_mysql6
	elif [ $mysql_version == '5.7' ]; then
                install_mysql7
	elif [ $mysql_version == '8.0' ]; then
                install_mysql8
	fi

        # add service
        if type systemctl > /dev/null 2>&1; then
                add_service
                logger "systemctl start ${SERVICE_NAME}"
                systemctl daemon-reload
                systemctl start ${SERVICE_NAME}
        else
                logger "/usr/sbin/chkconfig on ${SERVICE_NAME}"
                /usr/sbin/chkconfig on ${SERVICE_NAME}
                logger "service ${SERVICE_NAME} start"
                service ${SERVICE_NAME} start
        fi

        temporary_password=$(grep 'Note' $MYSQL_DATA_DIR/error.log | grep 'temporary password' | awk -F ': ' '{print $2}')
        logger "temporary password is ${temporary_password}"
        $MYSQL_HOME/bin/mysql -uroot -p${temporary_password} -P${PORT} --socket=$MYSQL_DATA_DIR/mysqld.sock --connect-expired-password -e "alter user 'root'@'localhost' identified with mysql_native_password by '${DEFAULT_PASSWORD}'"
        logger "update root@localhost password to ${DEFAULT_PASSWORD}"
	
}


postinstall(){
        
	cat > /etc/profile.d/${SERVICE_NAME}.sh <<- EOF
MYSQL_HOME=$MYSQL_HOME
PATH=\$PATH:\$MYSQL_HOME/bin
EOF
        logger "/etc/profile.d/${SERVICE_NAME}.sh created."

}


preinstall
preinstall_system
install
postinstall

echo "MySQL install successfully."


exit 0

# run....
sh mysql-install.sh \
--install-dir=/usr/local/ \
--server-id=1234 \
 --service-name=mysqld1.service \
 --download-url=https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.21-linux-glibc2.12-x86_64.tar.xz \
 --home=/usr/local/mysql8


# remove mysql env...
 rm -rf /usr/local/mysql8
 rm -rf /usr/local/mysql-8.0.21-linux-glibc2.12-x86_64
 rm -rf /etc/mysql8
 rm -rf /data/
 systemctl daemon-reload
 systemctl stop mysqld1.service
