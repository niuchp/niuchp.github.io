---
layout: post
title: etcd集群安装及基本操作
categories: [etcd, 大数据]
description: 介绍etcd集群的常用安装方式，以及基本操作
keywords: etcd cluster, etcdctl
---

> etcd 是 kubernetes 中默认使用的键值存储系统，相当于是 kubernetes 集群的大脑，那么 etcd 怎么安装使用呢？下面为常用的集群配置及基本操作。

etcd 是一个用于共享配置和服务的高可用键值存储系统，由 CoreOS 使用开发并作为 CoreOS 的基础服务启动。etcd 的灵感来源于 Apache ZooKeeper 和 doozer，其特点：

· 简单：可用 curl 进行操作（HTTP+JSON）   
· 安全：可使用 SSL 客户端证书验证  
· 快速：基准测试在每个实例 1000 次写入每秒  
· 可靠: 使用 Raft 协议来进行合理的分布式  

### 官方网站

<https://github.com/coreos/etcd/>  

### 安装环境

操作系统： CentOS7  
etcd版本： 3.0.4  
3节点集群示例  
etcd0: 192.168.8.101  
etcd1: 192.168.8.102  
etcd2: 192.168.8.103  

### 安装etcd集群

#### 一、安装软件包

*三个节点都执行*

```bash
curl -sSL https://github.com/coreos/etcd/releases/download/v3.0.4/etcd-v3.0.4-linux-amd64.tar.gz|tar -xvf - --gzip
cp -af etcd-v3.0.4-linux-amd64/{etcd,etcdctl} /usr/local/bin
chmod +x /usr/local/bin/{etcd,etcdctl}
```
#### 二、配置etcd

<https://github.com/coreos/etcd/blob/master/Documentation/op-guide/clustering.md>  
cluster帮助文档  
etcd-v3.0.4-linux-amd64/Documentation/op-guide/clustering.md  
This guide will cover the following mechanisms for bootstrapping an etcd cluster:

* [Static](#static)
* [etcd Discovery](#etcd-discovery)
* [DNS Discovery](#dns-discovery)  

目前支持三种发现方式，Static适用于有固定IP的主机节点，etcd Discovery适用于DHCP环境，DNS Discovery依赖DNS SRV记录


*提示：etcd支持ssl/tls,详见官方文档  
<https://github.com/coreos/etcd/blob/master/Documentation/op-guide/security.md>*

**以下使用static方式**

节点一: etcd0: 192.168.8.101  
```bash
etcd --name etcd0 --data-dir /opt/etcd \
  --initial-advertise-peer-urls http://192.168.8.101:2380 \
  --listen-peer-urls http://192.168.8.101:2380 \
  --listen-client-urls http://192.168.8.101:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.8.101:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster etcd0=http://192.168.8.101:2380,etcd1=http://192.168.8.102:2380,etcd2=http://192.168.8.103:2380 \
  --initial-cluster-state new
```

节点二: etcd1: 192.168.8.102  
```bash
etcd --name etcd1 --data-dir /opt/etcd \
  --initial-advertise-peer-urls http://192.168.8.102:2380 \
  --listen-peer-urls http://192.168.8.102:2380 \
  --listen-client-urls http://192.168.8.102:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.8.102:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster etcd0=http://192.168.8.101:2380,etcd1=http://192.168.8.102:2380,etcd2=http://192.168.8.103:2380 \
  --initial-cluster-state new
```

节点三: etcd2: 192.168.8.103  
```bash
etcd --name etcd2 --data-dir /opt/etcd \
  --initial-advertise-peer-urls http://192.168.8.103:2380 \
  --listen-peer-urls http://192.168.8.103:2380 \
  --listen-client-urls http://192.168.8.103:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.8.103:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster etcd0=http://192.168.8.101:2380,etcd1=http://192.168.8.102:2380,etcd2=http://192.168.8.103:2380 \
  --initial-cluster-state new 
  ```
  **说明**  
2379 是用于监听客户端请求，2380 用于集群通信，--data-dir指定数据存放目录  
注意:  
上面的初始化只是在集群初始化时运行一次，之后服务有重启，必须要去除掉initial参数，否则报错。  
请使用如下类似命令:  
```bash
etcd --name etcd2   --data-dir /opt/etcd \
  --listen-peer-urls http://192.168.8.103:2380 \
  --listen-client-urls http://192.168.8.103:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.8.103:2379 
```

#### 三、systemd管控

创建 etcd.service  （以 etcd0 为例）
```bash
cat >/lib/systemd/system/etcd.service <<HERE
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/opt/etcd/
ExecStart=/usr/local/bin/etcd --name etcd0 --data-dir /opt/etcd \
  --initial-advertise-peer-urls http://192.168.8.101:2380 \
  --listen-peer-urls http://192.168.8.101:2380 \
  --listen-client-urls http://192.168.8.101:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.8.101:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster etcd0=http://192.168.8.101:2380,etcd1=http://192.168.8.102:2380,etcd2=http://192.168.8.103:2380 \
  --initial-cluster-state new
Restart=on-failure
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
```
启动etcd服务  
```bash
[root@node1 ~]# systemctl enable etcd
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
[root@node1 ~]# systemctl start etcd
[root@node1 ~]# systemctl status etcd
●etcd.service - Etcd Server
  Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
  Active: active (running) since 2018-01-23 15:06:30 CST; 8min ago
 Main PID: 12099 (etcd)
  CGroup: /system.slice/etcd.service
         └─12099 /usr/local/bin/etcd --name etcd0 --data-dir /opt/etcd
......
```
### etcd集群管理

官方地址  
<https://github.com/coreos/etcd/blob/master/Documentation/op-guide/maintenance.md>  

```bash
[root@node3 ~]# etcdctl --version
etcdctl version: 3.0.4
 
 
API version: 2
COMMANDS:
    backup         backup an etcd directory
    cluster-health  check the health of the etcd cluster
    mk            make a new key with a given value
    mkdir          make a new directory
    rm            remove a key or a directory
    rmdir          removes the key if it is an empty directory or a key-value pair
    get           retrieve the value of a key
    ls            retrieve a directory
    set           set the value of a key
    setdir         create a new directory or update an existing directory TTL
    update         update an existing key with a given value
    updatedir      update an existing directory
    watch          watch a key for changes
    exec-watch     watch a key for changes and exec an executable
    member         member add, remove and list subcommands
    import         import a snapshot to a cluster
    user          user add, grant and revoke subcommands
    role          role add, grant and revoke subcommands
    auth          overall auth controls
```

#### 一、集群健康状态  
```bash
[root@node3 ~]# etcdctl cluster-health
member 2947dd07df9e44da is healthy: got healthy result from http://192.168.8.102:2379
member 571bf93ce7760601 is healthy: got healthy result from http://192.168.8.101:2379
member b200a8bec19bd22e is healthy: got healthy result from http://192.168.8.103:2379
cluster is healthy
```

#### 二、集群成员查看  
```bash
[root@node3 ~]# etcdctl member list
2947dd07df9e44da: name=etcd1 peerURLs=http://192.168.8.102:2380 clientURLs=http://192.168.8.102:2379 isLeader=false
571bf93ce7760601: name=etcd0 peerURLs=http://192.168.8.101:2380 clientURLs=http://192.168.8.101:2379 isLeader=true
b200a8bec19bd22e: name=etcd2 peerURLs=http://192.168.8.103:2380 clientURLs=http://192.168.8.103:2379 isLeader=false
```

#### 三、删除集群成员  
```bash
[root@node2 ~]# etcdctl member remove b200a8bec19bd22e 
Removed member 4d11141f72b2744c from cluster
[root@node2 ~]# etcdctl member list
2947dd07df9e44da: name=etcd1 peerURLs=http://192.168.8.102:2380 clientURLs=http://192.168.8.102:2379 isLeader=false
571bf93ce7760601: name=etcd0 peerURLs=http://192.168.8.101:2380 clientURLs=http://192.168.8.101:2379 isLeader=true
```

#### 四、添加集群成员  
官方说明：
<https://github.com/coreos/etcd/blob/master/Documentation/op-guide/runtime-configuration.md>  
*注意:步骤很重要，不然会报集群ID不匹配*
```bash
[root@node2 ~]# etcdctl member add --help
NAME:
  etcdctl member add - add a new member to the etcd cluster
USAGE:
  etcdctl member add
```

1.将目标节点添加到集群  
```bash
[root@node2 ~]# etcdctl member add etcd2 http://192.168.8.103:2380
Added member named etcd2 with ID 28e0d98e7ec15cd4 to cluster

ETCD_NAME="etcd2"
ETCD_INITIAL_CLUSTER="etcd2=http://192.168.8.103:2380,etcd1=http://192.168.8.102:2380,etcd0=http://192.168.8.101:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
[root@node2 ~]# etcdctl member list
2947dd07df9e44da: name=etcd1 peerURLs=http://192.168.8.102:2380 clientURLs=http://192.168.8.102:2379 isLeader=false
571bf93ce7760601: name=etcd0 peerURLs=http://192.168.8.101:2380 clientURLs=http://192.168.8.101:2379 isLeader=true
d4f257d2b5f99b64[unstarted]: peerURLs=http://192.168.8.103:2380
```
此时，集群会为目标节点生成一个唯一的member ID  

2.清空目标节点的data-dir  
```bash
[root@node3 ~]#rm -rf /opt/etcd
```
*注意:节点删除后，集群中的成员信息会更新，新节点加入集群是作为一个全新的节点加入，如果data-dir有数据，etcd启动时会读取己经存在的数据，启动时仍然用的老member ID,也会造成，集群不无法加入，所以一定要清空新节点的data-dir*
```bash
2016-08-12 01:59:41.084928 E | rafthttp: failed to find member 2947dd07df9e44da in cluster ce2f2517679629de
2016-08-12 01:59:41.133698 W | rafthttp: failed to process raft message (raft: stopped)
2016-08-12 01:59:41.135746 W | rafthttp: failed to process raft message (raft: stopped)
2016-08-12 01:59:41.170915 E | rafthttp: failed to find member 2947dd07df9e44da in cluster ce2f2517679629de
```

3.在目标节点上启动etcd  
```bash
etcd --name etcd2 --data-dir /opt/etcd \
 --initial-advertise-peer-urls http://192.168.8.103:2380 \
 --listen-peer-urls http://192.168.8.103:2380 \
 --listen-client-urls http://192.168.8.103:2379,http://127.0.0.1:2379 \
 --advertise-client-urls http://192.168.8.103:2379 \
 --initial-cluster-token etcd-cluster-1 \
 --initial-cluster etcd0=http://192.168.8.101:2380,etcd1=http://192.168.8.102:2380,etcd2=http://192.168.8.103:2380 \
 --initial-cluster-state existing
 ```

*注意:这里的initial标记一定要指定为existing,如果为new则会自动生成一个新的member ID,和前面添加节点时生成的ID不一致，故日志中会报节点ID不匹配的错*
```bash
[root@node2 ~]# etcdctl member list
28e0d98e7ec15cd4: name=etcd2 peerURLs=http://192.168.8.103:2380 clientURLs=http://192.168.8.103:2379 isLeader=false
2947dd07df9e44da: name=etcd1 peerURLs=http://192.168.8.102:2380 clientURLs=http://192.168.8.102:2379 isLeader=false
571bf93ce7760601: name=etcd0 peerURLs=http://192.168.8.101:2380 clientURLs=http://192.168.8.101:2379 isLeader=true
```

#### 五、增删改查  
```bash
[root@node3 ~]# etcdctl set foo "bar"
bar
[root@node3 ~]# etcdctl get foo
bar
[root@node3 ~]# etcdctl mkdir hello
[root@node3 ~]# etcdctl ls
/foo
/hello
[root@node3 ~]# etcdctl --output extended get foo
Key: /foo
Created-Index: 9
Modified-Index: 9
TTL: 0
Index: 10
bar
[root@node3 ~]# etcdctl --output json get foo
{"action":"get","node":{"key":"/foo","value":"bar","nodes":null,"createdIndex":9,"modifiedIndex":9},"prevNode":null}
[root@node2 ~]# etcdctl update foo "etcd cluster is ok"
etcd cluster is ok
[root@node2 ~]# etcdctl get foo
etcd cluster is ok
[root@node3 ~]# etcdctl import --snap/opt/etcd/member/snap/db 
starting to import snapshot /opt/etcd/member/snap/db with 10 clients
2016-08-12 01:18:17.281921 I | entering dir: /
finished importing 0 keys
```
#### REST API  
<https://github.com/coreos/etcd/tree/master/Documentation/learning>
```bash
[root@node1 ~]# curl 192.168.8.101:2379/v2/keys 
{"action":"get","node":{"dir":true,"nodes":[{"key":"/foo","value":"etcd cluster is ok","modifiedIndex":28,"createdIndex":9},{"key":"/hello","dir":true,"modifiedIndex":10,"createdIndex":10},{"key":"/registry","dir":true,"modifiedIndex":47,"createdIndex":47}]}}
[root@node1 ~]# curl -fs -X PUT 192.168.8.101:2379/v2/keys/_test
{"action":"set","node":{"key":"/_test","value":"","modifiedIndex":1439,"createdIndex":1439}}
[root@node1 ~]# curl -X GET 192.168.8.101:2379/v2/keys/_test
{"action":"get","node":{"key":"/_test","value":"","modifiedIndex":1439,"createdIndex":1439}}
```
