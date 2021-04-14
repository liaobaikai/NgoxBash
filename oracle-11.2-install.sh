#!/bin/bash
# @author: baikai.liao@qq.com
# @version: 1.0.2
# @date: 2021-03-10

ORACLE_ROOT=/oracle
ORACLE_BASE=$ORACLE_ROOT/app/oracle
ORACLE_GRP_OINSTALL=oinstall
ORACLE_GRP_DBA=dba
ORACLE_GRP_OPER=oper
ORACLE_USR_ORACLE=oracle
ORACLE_USR_PASSWD=oracle
SORT_ROOT=/root

preinstall_task_for_linux(){
        mount -t tmpfs shmfs -o size=7g /dev/shm
        sed -i '/shmfs/d' /etc/fstab 
        cat >> /etc/fstab <<- EOF
        shmfs /dev/shm tmpfs size=7g 0
EOF
}

preinstall_package_for_linux(){
        orainstall_package_file=/tmp/orainstall.package.txt
        cat > $orainstall_package_file <<- EOF
binutils-2.23.52.0.1-12.el7.x86_64 
compat-libcap1-1.10-3.el7.x86_64 
compat-libstdc++-33-3.2.3-71.el7.i686
compat-libstdc++-33-3.2.3-71.el7.x86_64
gcc-4.8.2-3.el7.x86_64 
gcc-c++-4.8.2-3.el7.x86_64 
glibc-2.17-36.el7.i686 
glibc-2.17-36.el7.x86_64 
glibc-devel-2.17-36.el7.i686 
glibc-devel-2.17-36.el7.x86_64 
ksh
libaio-0.3.109-9.el7.i686 
libaio-0.3.109-9.el7.x86_64 
libaio-devel-0.3.109-9.el7.i686 
libaio-devel-0.3.109-9.el7.x86_64 
libgcc-4.8.2-3.el7.i686 
libgcc-4.8.2-3.el7.x86_64 
libstdc++-4.8.2-3.el7.i686 
libstdc++-4.8.2-3.el7.x86_64 
libstdc++-devel-4.8.2-3.el7.i686 
libstdc++-devel-4.8.2-3.el7.x86_64 
libXi-1.7.2-1.el7.i686 
libXi-1.7.2-1.el7.x86_64 
libXtst-1.2.2-1.el7.i686 
libXtst-1.2.2-1.el7.x86_64 
make-3.82-19.el7.x86_64 
sysstat-10.1.5-1.el7.x86_64 
unixODBC-2.3.1-11 (32 bit) or later
unixODBC-2.3.1-11 (64 bit) or later
unixODBC-devel-2.3.1-11 (32 bit) or later
unixODBC-devel-2.3.1-11 (64 bit) or later
EOF
        if type dnf > /dev/null 2>&1; then
                cat $orainstall_package_file | awk -F '-' '{print "dnf install -y "$1"*"}' | sort | uniq > /tmp/orainstall.package.sh
                # desktop
                #echo 'dnf -y groupinstall "GNOME Desktop"' >> /tmp/orainstall.package.sh
                echo 'dnf -y install elfutils-libelf-devel' >> /tmp/orainstall.package.sh
        elif type yum > /dev/null 2>&1; then
                cat $orainstall_package_file | awk -F '-' '{print "yum install -y "$1"*"}' | sort | uniq > /tmp/orainstall.package.sh
                #echo 'yum -y groupinstall "GNOME Desktop"' >> /tmp/orainstall.package.sh
                echo 'yum install -y elfutils-libelf-devel' >> /tmp/orainstall.package.sh
        fi
        sh /tmp/orainstall.package.sh
}

# add user & group
preinstall_user_and_group_for_linux(){
        
        has_grp_oinstall=$(grep $ORACLE_GRP_OINSTALL /etc/group | wc -l)
        has_grp_dba=$(grep $ORACLE_GRP_DBA /etc/group | wc -l)
        has_grp_oper=$(grep $ORACLE_GRP_OPER /etc/group | wc -l)
        has_usr_oracle=$(grep $ORACLE_USR_ORACLE /etc/passwd | wc -l)

        if [ $has_grp_oinstall -eq 0 ]; then
                /usr/sbin/groupadd oinstall
        fi
        if [ $has_grp_dba -eq 0 ]; then
                /usr/sbin/groupadd dba
        fi
        if [ $has_grp_oper -eq 0 ]; then
                /usr/sbin/groupadd oper
        fi
        if [ $has_usr_oracle -eq 0 ]; then
                /usr/sbin/useradd -g $ORACLE_GRP_OINSTALL -G $ORACLE_GRP_DBA,$ORACLE_GRP_OPER $ORACLE_USR_ORACLE
                passwd $ORACLE_USR_ORACLE --stdin <<- EOF
$ORACLE_USR_PASSWD
EOF
        fi

        if [ ! -d $ORACLE_BASE ]; then
                mkdir -p $ORACLE_BASE
                chown -R $ORACLE_USR_ORACLE:$ORACLE_GRP_OINSTALL $ORACLE_ROOT/*
        fi

        has_config=$(grep 'ORACLE_BASE' /home/$ORACLE_USR_ORACLE/.bash_profile | wc -l)
        if [ $has_config -eq 0 ]; then
                cat >> /home/$ORACLE_USR_ORACLE/.bash_profile <<- EOF
ORACLE_SID=baika
ORACLE_BASE=$ORACLE_BASE
ORACLE_HOME=\$ORACLE_BASE/product/11.2.0/db_1
PATH=\$PATH:\$ORACLE_HOME/bin
NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export ORACLE_SID ORACLE_BASE ORACLE_HOME PATH NLS_LANG

EOF
        fi
}

preinstall_system_for_linux(){
        SELINUX=/etc/selinux/config
        LIMITS=/etc/security/limits.conf
        SYSCTL=/etc/sysctl.conf

        if [ -f $SELINUX ]; then
                sed -i 's/^SELINUX=.*$/SELINUX=disabled/' $SELINUX 1 2> /dev/null
                echo "Change $SELINUX SELINUX=disabled..."
        else
                echo "Skip: $SELINUX not exists!"
        fi

	# /etc/security/limits.conf
        if [ -f $LIMITS ]; then
	        is_add_ulimit=$(grep '^oracle' $LIMITS | wc -l)
                if [ $is_add_ulimit -ne 8 ]; then 
                        cat >> $LIMITS <<- EOF

oracle   soft    nofile   1024   
oracle   hard    nofile   65536   
oracle   soft    nproc    16384   
oracle   hard    nproc    16384   
oracle   soft    stack    10240   
oracle   hard    stack    32768  
oracle   hard    memlock  134217728  
oracle   soft    memlock  134217728  

EOF
                        echo "Change $LIMITS ulimit..."
	        fi
        else
               echo "Skip: $LIMITS not exists!" 
        fi
	
        if [ -f $SYSCTL ]; then
                cat >> $SYSCTL <<- EOF

fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2097152
kernel.shmmax = 4294967295
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576

EOF
                /sbin/sysctl -p
        else
              echo "Skip: $SYSCTL not exists!"   
        fi

        if [ -f /etc/pam.d/login ]; then
                cat >> /etc/pam.d/login <<- EOF
session         required        pam_limits.so
EOF
        fi

        # disable firewalld ?
        if type systemctl > /dev/null 2>&1; then
                systemctl disable firewalld.service
                systemctl stop firewalld.service
        elif type service > /dev/null 2>&1; then
                service iptables stop
        fi
}



ready_stage_for_linux(){
        STAGE_ROOT=$ORACLE_ROOT
        mv $SORT_ROOT/*.zip $STAGE_ROOT
        chown -R $ORACLE_USR_ORACLE:$ORACLE_GRP_OINSTALL $STAGE_ROOT
        su - $ORACLE_USR_ORACLE
        cd $STAGE_ROOT
        unzip p13390677_112040_Linux-x86-64_1of7.zip
        unzip p13390677_112040_Linux-x86-64_2of7.zip
}


operation_system=`uname -a | awk '{print $1}'`
case "$operation_system" in
        Darwin) echo "Not supported MacOS." ;;
        Linux)
                preinstall_task_for_linux
                preinstall_package_for_linux
                preinstall_user_and_group_for_linux
                preinstall_system_for_linux
                #ready_stage_for_linux
                ;;
esac


#########################################################
exit 0
#               auto config end....
#########################################################


# install oracle home through command line
cd /oracle/database/response/
cp db_install.rsp db_install2.rsp
[oracle@liaobaikai response]$ grep -v '^$' db_install2.rsp | grep -v '^#' | grep -v '^oracle.install.db.config'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=liaobaikai
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/oracle/app/inventory
SELECTED_LANGUAGES=en
ORACLE_HOME=/oracle/app/oracle/product/11.2.0/db_1
ORACLE_BASE=/oracle/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.EEOptionsSelection=false
oracle.install.db.optionalComponents=oracle.rdbms.partitioning:11.2.0.4.0,oracle.oraolap:11.2.0.4.0,oracle.rdbms.dm:11.2.0.4.0,oracle.rdbms.dv:11.2.0.4.0,oracle.rdbms.lbac:11.2.0.4.0,oracle.rdbms.rat:11.2.0.4.0
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=oper
oracle.install.db.CLUSTER_NODES=
oracle.install.db.isRACOneInstall=
oracle.install.db.racOneServiceName=
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=
SECURITY_UPDATES_VIA_MYORACLESUPPORT=
DECLINE_SECURITY_UPDATES=true                   <<<<<<<<<<<<< 必须设置为 true
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PWD=
PROXY_REALM=
COLLECTOR_SUPPORTHUB_URL=
oracle.installer.autoupdates.option=
oracle.installer.autoupdates.downloadUpdatesLoc=
AUTOUPDATES_MYORACLESUPPORT_USERNAME=
AUTOUPDATES_MYORACLESUPPORT_PASSWORD=

[oracle@liaobaikai ~]$ /oracle/database/runInstaller -silent -debug -responseFile /oracle/database/response/db_install2.rsp 


----

.....
INFO: ------------------List of failed Tasks------------------
INFO: *********************************************
INFO: Package: pdksh-5.2.14: This is a prerequisite condition to test whether the package "pdksh-5.2.14" is available on the system.
INFO: Severity:IGNORABLE
INFO: OverallStatus:VERIFICATION_FAILED
INFO: -----------------End of failed Tasks List----------------
WARNING: [WARNING] [INS-13014] Target environment do not meet some optional requirements.
   CAUSE: Some of the optional prerequisites are not met. See logs for details. /tmp/OraInstall2021-03-11_10-45-23PM/installActions2021-03-11_10-45-23PM.log
   ACTION: Identify the list of failed prerequisite checks from the log: /tmp/OraInstall2021-03-11_10-45-23PM/installActions2021-03-11_10-45-23PM.log. Then either from the log file or from installation manual find the appropriate confi
guration to meet the prerequisites and fix it manually.

.....
.....

silent Message = 
OiifbConfigController::MyProgress: Action end event received
OiifbConfigController::MyProgress: Action status = PERFORMED_SUCCESS
OiifbConfigController:: actionEnd event received from config fw , actionID.getSelfID() = configuration action State = 0
OiifbConfigController::Action state is TOOLS SUCCEEDED
OiifbConfigController::It is not a silent install and not a deinstall session,
 so trying to have the UI updation done by calling GraphicConfigPageHandler.handleActionEnd()
OiifbConfigController::Trying to close the output stream
OiifbConfigController::launchAggregatesForAdditionalUtil end
OiifbConfigController:: launchConfigToolsForAdditionalUtilityExecution end with return value0
The installation of Oracle Database 11g was successful.
Please check '/oracle/app/inventory/logs/silentInstall2021-03-11_10-45-23PM.log' for more details.

As a root user, execute the following script(s):
	1. /oracle/app/inventory/orainstRoot.sh
	2. /oracle/app/oracle/product/11.2.0/db_1/root.sh


Successfully Setup Software.
copying /oracle/app/inventory/logs/oraInstall2021-03-11_10-45-23PM.out to /oracle/app/oracle/product/11.2.0/db_1/cfgtoollogs/oui/oraInstall2021-03-11_10-45-23PM.out
copying /oracle/app/inventory/logs/silentInstall2021-03-11_10-45-23PM.log to /oracle/app/oracle/product/11.2.0/db_1/cfgtoollogs/oui/silentInstall2021-03-11_10-45-23PM.log
copying /oracle/app/inventory/logs/oraInstall2021-03-11_10-45-23PM.err to /oracle/app/oracle/product/11.2.0/db_1/cfgtoollogs/oui/oraInstall2021-03-11_10-45-23PM.err
copying /oracle/app/inventory/logs/installActions2021-03-11_10-45-23PM.log to /oracle/app/oracle/product/11.2.0/db_1/cfgtoollogs/oui/installActions2021-03-11_10-45-23PM.log



# oracle11gR2
wget https://vault.centos.org/5.11/os/x86_64/CentOS/pdksh-5.2.14-37.el5_8.1.x86_64.rpm
rpm -qa | grep ksh | xargs rpm -e 
rpm -ivh pdksh-5.2.14-37.el5_8.1.x86_64.rpm


#--------------------
#最后执行脚本：
/oracle/app/inventory/orainstRoot.sh
/oracle/app/oracle/product/11.2.0/db_1/root.sh


# error in invoking target 'agent nmhs' of make file ins_emagent.mk while installing Oracle 11.2.0.4 on Linux (Doc ID 2299494.1)
# Edit $ORACLE_HOME/sysman/lib/ins_emagent.mk, search for the line
# $(MK_EMAGENT_NMECTL)
# 
# Then replace the line with
# $(MK_EMAGENT_NMECTL) -lnnz11
# 
# Then click “Retry” button to continue.

sed -i 's/\$(MK_EMAGENT_NMECTL)/\$(MK_EMAGENT_NMECTL) -lnnz11/' $ORACLE_HOME/sysman/lib/ins_emagent.mk 



#------------------------------------------------------------------------------------------------
#               DBCA Silent
#------------------------------------------------------------------------------------------------
[oracle@liaobaikai ~]$ cp $ORACLE_HOME/assistants/dbca/dbca.rsp ~/dbca.rsp
[oracle@liaobaikai ~]$ mkdir $ORACLE_BASE/oradata

[oracle@liaobaikai ~]$ grep -v '^$' dbca.rsp | grep -v '^#' | grep -v '^oracle.install.db.config'
[GENERAL]
RESPONSEFILE_VERSION = "11.2.0"
OPERATION_TYPE = "createDatabase"
[CREATEDATABASE]
GDBNAME = "baika.liaobaikai.com"
SID = "baika"
TEMPLATENAME = "General_Purpose.dbc"
DATAFILEDESTINATION =
CHARACTERSET = "ZHS16GBK"
NATIONALCHARACTERSET= "UTF8"
SAMPLESCHEMA=TRUE
TOTALMEMORY = "800"

[oracle@liaobaikai ~]$ $ORACLE_HOME/bin/dbca -silent -responseFile ~/dbca.rsp
Enter SYS user password: 
 
Enter SYSTEM user password: 
 
Copying database files
1% complete
3% complete
11% complete
18% complete
26% complete
37% complete
Creating and starting Oracle instance
40% complete
45% complete
50% complete
55% complete
56% complete
57% complete
60% complete
62% complete
Completing Database Creation
66% complete
70% complete
73% complete
85% complete
96% complete
100% complete
Look at the log file "/oracle/app/oracle/cfgtoollogs/dbca/baika/baika.log" for further details.
[oracle@liaobaikai ~]$ ps -ef | grep ora_
oracle   19515     1  0 23:06 ?        00:00:00 ora_pmon_baika
oracle   19517     1  0 23:06 ?        00:00:00 ora_psp0_baika
oracle   19519     1  0 23:06 ?        00:00:00 ora_vktm_baika
oracle   19523     1  0 23:06 ?        00:00:00 ora_gen0_baika
oracle   19525     1  0 23:06 ?        00:00:00 ora_diag_baika
oracle   19527     1  0 23:06 ?        00:00:00 ora_dbrm_baika
oracle   19529     1  0 23:06 ?        00:00:00 ora_dia0_baika
oracle   19531     1  0 23:06 ?        00:00:00 ora_mman_baika
oracle   19533     1  0 23:06 ?        00:00:00 ora_dbw0_baika
oracle   19535     1  0 23:06 ?        00:00:00 ora_lgwr_baika
oracle   19537     1  0 23:06 ?        00:00:00 ora_ckpt_baika
oracle   19539     1  0 23:06 ?        00:00:00 ora_smon_baika
oracle   19541     1  0 23:06 ?        00:00:00 ora_reco_baika
oracle   19543     1  0 23:06 ?        00:00:00 ora_mmon_baika
oracle   19545     1  0 23:06 ?        00:00:00 ora_mmnl_baika
oracle   19547     1  0 23:06 ?        00:00:00 ora_d000_baika
oracle   19549     1  0 23:06 ?        00:00:00 ora_s000_baika
oracle   19561     1  0 23:06 ?        00:00:00 ora_qmnc_baika
oracle   19577     1  0 23:06 ?        00:00:00 ora_cjq0_baika
oracle   19587     1  0 23:07 ?        00:00:00 ora_q000_baika
oracle   19589     1  0 23:07 ?        00:00:00 ora_q001_baika
oracle   19608 18454  0 23:07 pts/0    00:00:00 grep --color=auto ora_
[oracle@liaobaikai ~]$ cd $ORACLE_HOME/dbs/
[oracle@liaobaikai dbs]$ ll
total 20
-rw-rw---- 1 oracle oinstall 1544 Mar 11 23:06 hc_baika.dat
-rw-r--r-- 1 oracle oinstall 2851 May 15  2009 init.ora
-rw-r----- 1 oracle oinstall   24 Mar 11 23:04 lkBAIKA
-rw-r----- 1 oracle oinstall 1536 Mar 11 23:06 orapwbaika
-rw-r----- 1 oracle oinstall 2560 Mar 11 23:07 spfilebaika.ora          <<<<<<<<<<< 生成spfile.
[oracle@liaobaikai dbs]$ 

#------------------------------------------------------------------------------------------------
#               config listener
#------------------------------------------------------------------------------------------------
cp $ORACLE_HOME/network/admin/samples/listener.ora cp $ORACLE_HOME/network/admin/listener.ora 

LISTENER =
  (ADDRESS_LIST=
        (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.1.115)(PORT=11521))
  )

# SID_LIST_<lsnr>
#   List of services the listener knows about and can connect 
#   clients to.  There is no default.  See the Net8 Administrator's
#   Guide for more information.
#
SID_LIST_LISTENER=
   (SID_LIST=
        (SID_DESC=
                        #BEQUEATH CONFIG
          #(GLOBAL_DBNAME=baika.liaobaikai.com)
          (SID_NAME=baika)
          (ORACLE_HOME=/oracle/app/oracle/product/11.2.0/db_1)
                        #PRESPAWN CONFIG
          #(PRESPAWN_MAX=20)
          #(PRESPAWN_LIST=
          # (PRESPAWN_DESC=(PROTOCOL=tcp)(POOL_SIZE=2)(TIMEOUT=1))
         #)
        )
       )


#------------------------------------------------------------------------------------------------
#               upgrade plugin -> psu
#------------------------------------------------------------------------------------------------

SQL> shutdown immediate

[oracle@liaobaikai oracle]$ unzip p28204707_112040_Linux-x86-64.zip
[oracle@liaobaikai oracle]$ unzip p6880880_112000_Linux-x86-64.zip
[oracle@liaobaikai oracle]$ mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak
[oracle@liaobaikai oracle]$ mv OPatch $ORACLE_HOME/OPatch
[oracle@liaobaikai oracle]$ $ORACLE_HOME/OPatch/opatch lsinventory
#### 打补丁
[oracle@liaobaikai 28204707]$ $ORACLE_HOME/OPatch/opatch apply
#### 
Stack Description: java.lang.RuntimeException: 
                                    To run in silent mode, OPatch requires a response file for Oracle Configuration Manager (OCM).
                                    Please run "/tmp/oracle-home-1616035828304331/OPatch/ocm/bin/emocmrsp" to generate an OCM response file. The generated response file
                                    can be reused on different platforms and in multiple OPatch silent installs.
                                    
                                    To regenerate an OCM response file, Please rerun "/tmp/oracle-home-1616035828304331/OPatch/ocm/bin/emocmrsp".
                                    
                                    	at oracle.opatch.OPatchSessionHelper.validateOCMOption(OPatchSessionHelper.java:3120)
                                    	at oracle.opatch.opatchutil.NApply.legacy_process(NApply.java:918)
                                    	at oracle.opatch.opatchutil.NApply.legacy_process(NApply.java:368)
                                    	at oracle.opatch.opatchutil.NApply.process(NApply.java:348)
                                    	at oracle.opatch.opatchutil.OUSession.napply(OUSession.java:1108)
                                    	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
                                    	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:39)
                                    	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:25)
                                    	at java.lang.reflect.Method.invoke(Method.java:597)
                                    	at oracle.opatch.UtilSession.process(UtilSession.java:355)
                                    	at oracle.opatch.OPatchSession.process(OPatchSession.java:2650)
                                    	at oracle.opatch.OPatch.process(OPatch.java:779)
                                    	at oracle.opatch.OPatch.main(OPatch.java:829)
                                    Caused by: oracle.opatch.OCMException: 
                                    To run in silent mode, OPatch requires a response file for Oracle Configuration Manager (OCM).
                                    Please run "/tmp/oracle-home-1616035828304331/OPatch/ocm/bin/emocmrsp" to generate an OCM response file. The generated response file
                                    can be reused on different platforms and in multiple OPatch silent installs.
.....

[oracle@liaobaikai oracle]$ $ORACLE_HOME/OPatch/ocm/bin/emocmrsp
--- 生成了 ocm.rsp文件
[oracle@liaobaikai 28204707]$ $ORACLE_HOME/OPatch/opatch apply -ocmrf /oracle/ocm.rsp
....
OPatch completed with warnings.