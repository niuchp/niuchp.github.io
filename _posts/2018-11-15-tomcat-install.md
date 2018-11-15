---
layout: post
title: Linux下安装tomcat
categories: tomcat
description: 在Linux环境中安装tomcat，并使用systemctl控制
keywords: tomcat, systemctl
---

# 前言

tomcat 是一款优秀的 web 应用服务器，可以用来运行 servlet。下文记录 tomcat 的安装以及使用 systemctl 命令进行控制的过程。
> systemctl命令是service和chkconfig命令的集合 service命令:用于启动、停止、重新启动和关闭系统服务，还可以显示所有系统服务的当前状态 chkconfig命令:用于更新（启动或停止）和查询系统服务的运行级信息

## 1、安装tomcat

### 1.1、下载二进制文件   
```bash
[root@master ~]# wget http://mirrors.hust.edu.cn/apache/tomcat/tomcat-9/v9.0.13/bin/apache-tomcat-9.0.13.tar.gz
```
### 1.2、解压文件   
```bash
[root@master ~]# tar -zxf apache-tomcat-9.0.13.tar.gz
```

### 1.3、移动文件到/opt下   
```bash
[root@master ~]# mv  apache-tomcat-9.0.13 /opt/apache-tomcat-9.0.13/
```

### 1.4、创建软链

```bash
[root@master opt]# ln -s /opt/apache-tomcat-9.0.13  /usr/local/tomcat
```

### 1.5、配置jdk环境变量

添加：
```
JAVA_HOME=/usr/java/default
JRE_HOME=$JAVA_HOME/jre
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
export JAVA_HOME PATH CLASSPATH
```

### 1.6、生效环境变量

```bash
[root@master opt]# source /etc/profile
```

### 1.7、配置tomcat端口（默认8080）
```bash
[root@master ~]# vim /usr/local/tomcat/conf/server.xml
#修改：
 <Connector port="8080" protocol="HTTP/1.1"
```

### 1.8、启动tomcat

```bash
[root@master ~]# /usr/local/tomcat/bin/startup.sh
```

### 1.9、验证
浏览器输入：http://IP:PROT

## 2、配置systemctl

### 2.1、新建tomcat.pid

```bash
[root@master ~]# cd /usr/local/tomcat-9.0.13
[root@master tomcat-9.0.13]# touch tomcat.pid
```

### 2.2、新建setenv.sh(catalina.sh调用）
```bash
[root@master tomcat-9.0.13]# cd bin
[root@master bin]# vim setenv.sh

#$CATALINA_BASE为tomcat安装的目录路径,将tomcat.pid指给了CATALINA_PID
CATALINA_PID="$CATALINA_BASE/tomcat.pid"
#设置tomcat启动的java内存参数
JAVA_OPTS="-server -XX:PermSize=256M -XX:MaxPermSize=1024m -Xms512M -Xmx1024M -XX:MaxNewSize=256m"
```

### 2.3、创建service文件

```bash
[root@master bin]# vim /usr/lib/systemd/system/tomcat.service

[Unit]
Description=Tomcat
After=syslog.target network.target remote-fs.target nss-lookup.target
[Service]
Type=forking
PIDFile=/usr/local/tomcat-9.0.13/tomcat.pid
ExecStart=/usr/local/tomcat-9.0.13/bin/startup.sh
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
[Install]
WantedBy=multi-user.target
```

### 2.4、测试

```bash
[root@master bin]# systemctl start tomcat.service
[root@master bin]# systemctl status tomcat.service
[root@master bin]# systemctl stop tomcat.service
```