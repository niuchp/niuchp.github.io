---
layout: post
title: mariadb的主从复制、主主复制、半同步复制的概念和方法
categories: mysql
description: mariadb的主从复制、主主复制、半同步复制的概念和方法
keywords: mysql,mariadb
---

这篇文章主要详细介绍了mariadb的主从复制、主主复制、半同步复制的概念和方法。
>参考http://www.jb51.net/article/97786.htm

主从服务器的时间要同步，数据库版本最好是一致的，以免造成函数处理、日志读取、日志解析等发生异常。
以下三个主从复制的设置是独立的。
注意防火墙和selinux的影响。

# **1、简单主从复制的实现**

## 1.1 服务器1操作

### 1）安装mariadb-server

[root@localhost ~]# yum -y install mariadb-server

### 2）编辑/etc/my.cnf文件
   在[mysqld]段的最后添加以下内容
   
	[root@localhost ~]# vim /etc/my.cnf
	skip_name_resolve = ON
	innodb_file_per_table = ON    
	server-id = 1 （id号不能跟从服务器相同）	
	log-bin = master-log （自定义二进制日志文件名）
### 3）授权可以复制本地数据库信息的主机
	[root@localhost ~]# systemctl start mariadb.service （启动mariadb server）
 
	[root@localhost ~]# mysql
	MariaDB [(none)]> grant replication slave,replication client on *.* to 'repluser'@'10.1.51.%' identified by 'replpasswd';
	 MariaDB [(none)]> flush privileges;
 
	MariaDB [(none)]> show master status\G （查看主服务器的状态信息，在从服务器中要用到）
	*************************** 1. row ***************************
	File: master-log.000003 （正在使用的二进制日志文件）
	Position: 497 （所处的位置）
	Binlog_Do_DB:
	Binlog_Ignore_DB:
## 1.2 从服务器的配置

### 1）安装mariadb-server

	[root@localhost ~]# yum -y install mariadb-server
### 2）编辑/etc/my.cnf文件
在[mysqld]段的最后添加以下内容

	[root@localhost ~]# vim /etc/my.cnf
    skip_name_resolve = ON
    innodb_file_per_table = ON
    server-id = 2 （id号不能跟主服务器相同）
    relay-log = slave-log （自定义二进制日志文件名）
### 3）设置要从哪个主服务器的那个位置开始同步
	[root@localhost ~]# systemctl start mariadb.service
 
	[root@localhost ~]# mysql
	 MariaDB [(none)]> change master to master_host='10.1.51.60',master_user='repluser',master_password='replpasswd',master_log_file='master-log.000003',master_log_pos=497;
 
	MariaDB [(none)]> start slave; （启动复制功能）
	MariaDB [(none)]> show slave status\G （查看从服务器的状态，下面显示的是部分内容）
	 Master_Host: 10.1.51.60
	 Master_User: repluser
	 Master_Port: 3306
	 Connect_Retry: 60
	 Master_Log_File: master-log.000003
	 Read_Master_Log_Pos: 497
	 Relay_Log_File: slave-log.000002
	 Relay_Log_Pos: 530
	 Relay_Master_Log_File: master-log.000003
	 Slave_IO_Running: Yes
	 Slave_SQL_Running: Yes
	 Master_Server_Id: 1
## 1.3 测试

### 1）在主服务器导入事先准备好的数据库

	[root@localhost ~]# mysql < hellodb.sql

### 2）在从服务器查看是否同步

	MariaDB [(none)]> show databases;
	+--------------------+
	| Database   |
	+--------------------+
	| information_schema |
	| hellodb   |（数据库已经同步）
	| mysql    |
	| performance_schema |
	| test    |
	+--------------------+
	MariaDB [(none)]> use hellodb;
	MariaDB [hellodb]> show tables; （hellodb数据库的表也是同步的）
	+-------------------+
	| Tables_in_hellodb |
	+-------------------+
	| classes   |
	| coc    |
	| courses   |
	| scores   |
	| students   |
	| teachers   |
	| toc    |
	+-------------------+
# **2、双主复制的实现**

## 2.1 安装MariaDB

*服务器1的操作：*

### 1）安装mariadb-server

	[root@localhost ~]# yum -y install mariadb-server
### 2）编辑/etc/my.cnf文件

	[root@localhost ~]# vim /etc/my.cnf
	在[mysqld]段的最后添加以下内容
	skip_name_resolve = ON
	innodb_file_per_table = ON
	server-id = 1 （id号不能跟从服务器相同）
	log-bin = master-log （自定义主服务器的二进制日志文件名）
	relay-log = slave-log （自定义从服务器的二进制日志文件名）
	auto_increment_offset = 1 
	auto_increment_increment = 2

### 3）启动服务

	[root@localhost ~]# systemctl start mariadb.service
	
	[root@localhost ~]#systemctl enable mariadb.service



*服务器2的操作：*

### 1）安装mariadb-server

	[root@localhost ~]# yum -y install mariadb-server
### 2）编辑/etc/my.cnf文件

	[root@localhost ~]# vim /etc/my.cnf
	skip_name_resolve = ON
	innodb_file_per_table = ON
	server-id = 2
	relay-log = slave-log
	lob-bin = master-log
	auto_increment_offset = 2 
	auto_increment_increment = 2


### 3）启动服务

	[root@localhost ~]# systemctl start mariadb.service
	
	[root@localhost ~]#systemctl enable mariadb.service


## 2.2 配置双主复制


### 1) 在服务器2上查看的master状态

*说明：记录数据，在服务器2上配置时会用到。*

	MariaDB [(none)]> show master status\G
	*************************** 1. row ***************************
	File: master-log.000003
	Position: 521
	Binlog_Do_DB:
	Binlog_Ignore_DB:
### 2）服务器1上进行如下配置

*说明：以下配置的内容为服务器2的IP及服务器2上查到的master数据。*

	[root@localhost ~]# mysql
	 
	MariaDB [(none)]> grant replication slave,replication client on *.* to 'repluser'@'192.168.1.%' identified by 'replpasswd';
	 
	MariaDB [(none)]> change master to master_host='192.168.1.188',master_user='repluser',master_password='replpasswd',master_log_file='master-log.000003',master_log_pos=521;
	 
	MariaDB [(none)]> start slave;
	 
	MariaDB [(none)]> SHOW SLAVE STATUS\G
	*************************** 1. row ***************************
	              Slave_IO_State: Waiting for master to send event
	                  Master_Host: 192.168.1.188
	                  Master_User: repluser
	                  Master_Port: 3306
	                Connect_Retry: 60
	              Master_Log_File: master-log.000003
	          Read_Master_Log_Pos: 521
	              Relay_Log_File: slave-log.000002
	                Relay_Log_Pos: 806
	        Relay_Master_Log_File: master-log.000003
	            Slave_IO_Running: Yes
	            Slave_SQL_Running: Yes
	              Replicate_Do_DB:
	          Replicate_Ignore_DB:
	          Replicate_Do_Table:
	      Replicate_Ignore_Table:
	      Replicate_Wild_Do_Table:
	  Replicate_Wild_Ignore_Table:
	                  Last_Errno: 0
	                  Last_Error:
	                Skip_Counter: 0
	          Exec_Master_Log_Pos: 521
	              Relay_Log_Space: 1094
	              Until_Condition: None
	              Until_Log_File:
	                Until_Log_Pos: 0
	          Master_SSL_Allowed: No
	          Master_SSL_CA_File:
	          Master_SSL_CA_Path:
	              Master_SSL_Cert:
	            Master_SSL_Cipher:
	              Master_SSL_Key:
	        Seconds_Behind_Master: 0
	Master_SSL_Verify_Server_Cert: No
	                Last_IO_Errno: 0
	                Last_IO_Error:
	              Last_SQL_Errno: 0
	              Last_SQL_Error:
	  Replicate_Ignore_Server_Ids:
	            Master_Server_Id: 2
	1 row in set (0.00 sec)

### 3）在服务器1查看master状态

	MariaDB [(none)]> show master status\G
	*************************** 1. row ***************************
	File: master-log.000003
	Position: 795
	Binlog_Do_DB: 
	Binlog_Ignore_DB:

### 4）服务器2上进行如下配置

*说明：以下的配置内容为服务器1的IP及服务器1中查到的master信息*
	[root@localhost ~]# mysql
	 
	 MariaDB [(none)]> grant replication slave,replication client on *.* to 'repluser'@'192.168.1.%' identified by 'replpasswd';
	 
	 MariaDB [(none)]> change master to master_host='192.168.1.187',master_user='repluser',master_password='replpasswd',master_log_file='master-log.000003',master_log_pos=795;
	 
	 MariaDB [(none)]> start slave;
	 
	 MariaDB [(none)]> show slave status\G
	*************************** 1. row ***************************
	              Slave_IO_State: Waiting for master to send event
	                  Master_Host: 192.168.1.187
	                  Master_User: repluser
	                  Master_Port: 3306
	                Connect_Retry: 60
	              Master_Log_File: master-log.000003
	          Read_Master_Log_Pos: 795
	              Relay_Log_File: slave-log.000002
	                Relay_Log_Pos: 530
	        Relay_Master_Log_File: master-log.000003
	            Slave_IO_Running: Yes
	            Slave_SQL_Running: Yes
	              Replicate_Do_DB:
	          Replicate_Ignore_DB:
	          Replicate_Do_Table:
	      Replicate_Ignore_Table:
	      Replicate_Wild_Do_Table:
	  Replicate_Wild_Ignore_Table:
	                  Last_Errno: 0
	                  Last_Error:
	                Skip_Counter: 0
	          Exec_Master_Log_Pos: 795
	              Relay_Log_Space: 818
	              Until_Condition: None
	              Until_Log_File:
	                Until_Log_Pos: 0
	          Master_SSL_Allowed: No
	          Master_SSL_CA_File:
	          Master_SSL_CA_Path:
	              Master_SSL_Cert:
	            Master_SSL_Cipher:
	              Master_SSL_Key:
	        Seconds_Behind_Master: 0
	Master_SSL_Verify_Server_Cert: No
	                Last_IO_Errno: 0
	                Last_IO_Error:
	              Last_SQL_Errno: 0
	              Last_SQL_Error:
	  Replicate_Ignore_Server_Ids:
	            Master_Server_Id: 1
	1 row in set (0.00 sec)

## 2.3 测试

### 1）在任意一台服务器上创建mydb数据库

	MariaDB [(none)]> create database mydb;

### 2）在另一台服务器上查看

	MariaDB [(none)]> show databases;
	+--------------------+
	| Database   |
	+--------------------+
	| information_schema |
	| mydb    |
	| mysql    |
	| performance_schema |
	| test    |
	+--------------------+
# **3、半同步复制的实现**

##3.1 在主服务器上的配置

### 1）安装mariadb-server

	[root@localhost ~]# yum -y install mariadb-server
### 2）编辑/etc/my.cnf

	[root@localhost ~]# vim /etc/my.cnf
	    skip_name_resolve = ON
	    innodb_file_per_table = ON
	    server-id = 1
	    log-bin = master-log

### 3）授权可以复制本地数据库信息的主机

	[root@localhost ~]# systemctl start mariadb.service （启动mariadb server）
	 
	[root@localhost ~]# mysql
	 MariaDB [(none)]> grant replication slave,replication client on *.* to 'repluser'@'10.1.51.%' identified by 'replpasswd';
	 MariaDB [(none)]> flush privileges;
	 
	MariaDB [(none)]> show master status\G （查看主服务器的状态信息，在从服务器中要用到）
	*************************** 1. row ***************************
	File: master-log.000003 （正在使用的二进制日志文件）
	Position: 245 （所处的位置）
	Binlog_Do_DB:
	Binlog_Ignore_DB:
### 4）安装rpl semi sync_master插件，并启用

	[root@localhost ~]# mysql
	 
	MariaDB [(none)]> install plugin rpl_semi_sync_master soname 'semisync_master.so';
	MariaDB [(none)]> set global rpl_semi_sync_master_enabled = ON;
	补充：
	MariaDB [(none)]> show plugins;（可查看插件是否激活）
	MariaDB [(none)]> show global variables like 'rpl_semi%';（可查看安装的插件是否启用）
	MariaDB [(none)]> show global status like '%semi%';（可查看从服务器的个数，此时是0个）

## 3.2从服务器的配置

### 1）安装mariadb-server

	[root@localhost ~]# yum -y install mariadb-server

### 2）编辑/etc/my.cnf文件
    在[mysqld]段的最后添加以下内容
	[root@localhost ~]# vim /etc/my.cnf
	skip_name_resolve = ON
	innodb_file_per_table = ON
	server-id = 2 （id号不能跟主服务器相同）
	relay-log = slave-log （自定义二进制日志文件名）
### 3）设置要从哪个主服务器的那个位置开始同步

	[root@localhost ~]# systemctl start mariadb.service
	 
	[root@localhost ~]# mysql
	 
	MariaDB [(none)]> change master to master_host='10.1.51.60',master_user='repluser',master_password='replpasswd',master_log_file='master-log.000003',master_log_pos=245;
### 4）安装rpl semi sync_slave插件并启用
	[root@localhost ~]# mysql
	 
	 MariaDB [(none)]> install plugin rpl_semi_sync_slave soname 'semisync_slave.so';
	 MariaDB [(none)]> set global rpl_semi_sync_slave_enabled = ON;
	 MariaDB [(none)]> start slave;
完成上面配置后，可以在主服务器上查看半同步复制的相关信息，命令如下：
	MariaDB [(none)]> show global status like '%semi%';
 Rpl_semi_sync_master_clients 1 （从服务器有一台）
### 3.3 测试

测试以个人实际情况而定
### 1）在主服务器上导入事先准备好的数据库hellodb.sql

	MariaDB [hellodb]> source /root/hellodb.sql;
### 2）在主服务器上查看半同步复制的状态
	MariaDB [hellodb]> show master status;
	+-------------------+----------+--------------+------------------+
	| File    | Position | Binlog_Do_DB | Binlog_Ignore_DB |
	+-------------------+----------+--------------+------------------+
	| master-log.000003 |  8102 |    |     |
	+-------------------+----------+--------------+------------------+
	 
	MariaDB [hellodb]> show global status like '%semi%';
	+--------------------------------------------+-------+
	| Variable_name        | Value |
	+--------------------------------------------+-------+
	| Rpl_semi_sync_master_clients    | 1  |
	| Rpl_semi_sync_master_net_avg_wait_time  | 1684 |
	| Rpl_semi_sync_master_net_wait_time   | 60630 |
	| Rpl_semi_sync_master_net_waits    | 36 |
	| Rpl_semi_sync_master_no_times    | 1  |
	| Rpl_semi_sync_master_no_tx     | 1  |
	| Rpl_semi_sync_master_status    | ON |
	| Rpl_semi_sync_master_timefunc_failures  | 0  |
	| Rpl_semi_sync_master_tx_avg_wait_time  | 1884 |
	| Rpl_semi_sync_master_tx_wait_time   | 65965 |
	| Rpl_semi_sync_master_tx_waits    | 35 |
	| Rpl_semi_sync_master_wait_pos_backtraverse | 0  |
	| Rpl_semi_sync_master_wait_sessions   | 0  |
	| Rpl_semi_sync_master_yes_tx    | 35 |
	+--------------------------------------------+-------+
### 3）在从服务器上查看是否同步
	MariaDB [(none)]> show databases;
	MariaDB [(none)]> use hellodb;
	MariaDB [hellodb]> select * from students;


# **4 补充：**

基于上面的半同步复制配置复制的过滤器，复制过滤最好在从服务器上设置，步骤如下

## 4.1 从服务器的配置

### 1）关闭mariadb server

	[root@localhost ~]# systemctl stop mariadb.service
### 2）编辑/etc/my.cnf文件
	[root@localhost ~]# vim /etc/my.cnf
	skip_name_resolve = ON
	innodb_file_per_table = ON
	server-id = 2
	relay-log = slave-log
	replicate-do-db = mydb （只复制mydb数据库的内容）
补充：常用的过滤选项如下

	Replicate_Do_DB=
	Replicate_Ignore_DB=
	Replicate_Do_Table=
	Replicate_Ignore_Table=
	Replicate_Wild_Do_Table=
	Replicate_Wild_Ignore_Table=
### 3）重启mariadb server

	[root@localhost ~]# systemctl start mariadb.service

### 4）重启mariadb server后，半同步复制功能将被关闭，因此要重新启动
	MariaDB [(none)]> show global variables like '%semi%';
	+---------------------------------+-------+
	| Variable_name     | Value |
	+---------------------------------+-------+
	| rpl_semi_sync_slave_enabled  | OFF |
	| rpl_semi_sync_slave_trace_level | 32 |
	+---------------------------------+-------+
	 
	MariaDB [(none)]> set global rpl_semi_sync_slave_enabled = ON;
	MariaDB [(none)]> stop slave;（需先关闭从服务器复制功能再重启）
	MariaDB [(none)]> start slave;
## 4.2测试

### 1）主服务器上的hellodb数据库创建一个新表semitable

	MariaDB [hellodb]> create table semitable (id int);
### 2）在从服务器上查看hellodb数据库是否有semitable
	MariaDB [(none)]> use hellodb
	MariaDB [hellodb]> show tables;（并没有）
	+-------------------+
	| Tables_in_hellodb |
	+-------------------+
	| classes   |
	| coc    |
	| courses   |
	| scores   |
	| students   |
	| teachers   |
	| toc    |
	+-------------------+
### 3）在主服务器上创建mydb数据库，并为其创建一个tbl1表

	MariaDB [hellodb]> create database mydb;
### 4）在从服务器上查看mydb数据库的是否有tbl1表

	MariaDB [hellodb]> use mydb;
	MariaDB [mydb]> show tables; （可以查看到）
	+----------------+
	| Tables_in_mydb |
	+----------------+
	| tbl1   |
	+----------------+

