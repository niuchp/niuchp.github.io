---
layout: post
title: CentOS7安装rancher2.x
categories: [rancher, kubernetes]
description: 在CentOS7中利用rancher安装并管理kubernetes集群
keywords: rancher, kubernetes
---

# CentOS7安装Rancher2.x

容器已然成为IT建设的潮流，目前最流行的容器管理、编排方案莫过于Kubernetes（简称K8S)，但是使用过K8S的小伙伴肯定和我一样爬坑无数。我曾经写过一套安装脚本用于公司内部环境部署，虽所简化了安装过程，但在管理多个K8S环境时（项目多数以整个集群为交付成果，开发测试时也划分了多个集群）仍然很犯难，Rancher对我而言最大的吸引点可能就在于此吧，参考官方文档实验后简单记录如下，便于日后回顾。

## 1、Rancher简介

Rancher是一套容器管理平台，它可以帮助组织在生产环境中轻松快捷的部署和管理容器。 Rancher可以轻松地管理各种环境的Kubernetes，满足IT需求并为DevOps团队提供支持。

Kubernetes不仅已经成为的容器编排标准，它也正在迅速成为各类云和虚拟化厂商提供的标准基础架构。Rancher用户可以选择使用Rancher Kubernetes Engine(RKE)创建Kubernetes集群，也可以使用GKE，AKS和EKS等云Kubernetes服务。 Rancher用户还可以导入和管理现有的Kubernetes集群。

Rancher支持各类集中式身份验证系统来管理Kubernetes集群。例如，大型企业的员工可以使用其公司Active Directory凭证访问GKE中的Kubernetes集群。IT管​​理员可以在用户，组，项目，集群和云中设置访问控制和安全策略。 IT管​​理员可以在单个页面对所有Kubernetes集群的健康状况和容量进行监控。

(引自[Rancher Labs](https://www.cnrancher.com/docs/rancher/v2.x/cn/overview/))

![](/images/posts/rancher/rancher-architecture.png)

## 2、组件版本
- 操作系统：CentOS7.2
- OS内核：3.10.0 (使用Overlay2需要升级内核至4.x）
- Rancher:2.1.1
- Docker: 17.03
- 集群IP地址划分：

|role|hostname|IP|
|-------|---------|--------|
|rancher-server|server|192.168.31.10|
|worker|node1|192.168.31.11|
|worker|node2|192.168.31.12|
|worker|node3|192.168.31.13|
|registry|harbor.kago.site|192.168.31.65|

## 3、基础环境安装
**1.  操作系统安装**

推荐使用“minimal install”最小安装模式，安装完毕后再按需安装“vim、ip-utils、net-tools”等工具。

**2.  配置主机名**

命令：hostnamectl set-hostname <hostname\>    
> 因为K8S的规定，主机名只支持包含 - 和 .(中横线和点)两种特殊符号，并且主机名不能出现重复。

**3. 关闭防火墙、selinux**

**4. kernel性能优化**

```bash
cat >> /etc/sysctl.conf<<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
EOF
```

## 4、安装docker
**1. 修改YUM源**

```bash
sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
cat > /etc/yum.repos.d/CentOS-Base.repo << EOF

[base]
name=CentOS-$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
        http://mirrors.aliyuncs.com/centos/$releasever/os/$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
        http://mirrors.aliyuncs.com/centos/$releasever/updates/$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
        http://mirrors.aliyuncs.com/centos/$releasever/extras/$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/centosplus/$basearch/
        http://mirrors.aliyuncs.com/centos/$releasever/centosplus/$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#contrib - packages by Centos Users
[contrib]
name=CentOS-$releasever - Contrib - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/contrib/$basearch/
        http://mirrors.aliyuncs.com/centos/$releasever/contrib/$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/$releasever/contrib/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

EOF
```

**2. 安装Docker-ce**

> 因为CentOS的安全限制，通过RKE安装K8S集群时候无法使用root账户。所以，建议CentOS用户使用非root用户来运行docker,不管是RKE还是custom安装k8s。

```bash
# 添加用户（可选）
sudo adduser `<new_user>`
# 为新用户设置密码
sudo passwd `<new_user>`
# 为新用户添加sudo权限
sudo echo '<new_user> ALL=(ALL) ALL' >> /etc/sudoers
# 卸载旧版本Docker软件
sudo yum remove docker \
              docker-client \
              docker-client-latest \
              docker-common \
              docker-latest \
              docker-latest-logrotate \
              docker-logrotate \
              docker-selinux \
              docker-engine-selinux \
              docker-engine \
              container*
# 定义安装版本
export docker_version=17.03.2
# step 1: 安装必要的一些系统工具
sudo yum update -y
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 bash-completion
# Step 2: 添加软件源信息
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# Step 3: 更新并安装 Docker-CE
sudo yum makecache all
version=$(yum list docker-ce.x86_64 --showduplicates | sort -r|grep ${docker_version}|awk '{print $2}')
sudo yum -y install --setopt=obsoletes=0 docker-ce-${version} docker-ce-selinux-${version}
# 如果已经安装高版本Docker,可进行降级安装(可选)
yum downgrade --setopt=obsoletes=0 -y docker-ce-${version} docker-ce-selinux-${version}
# 把当前用户加入docker组
sudo usermod -aG docker `<new_user>`
# 设置开机启动
sudo systemctl enable docker
```

>Docker-Engine Docker官方已经不推荐使用，请安装Docker-CE。


**3. 配置Docker**
daemon.json默认位于/etc/docker/daemon.json，如果没有可手动创建，基于systemd管理的系统都是相同的路径。通过修改daemon.json来改过Docker配置，也是Docker官方推荐的方法。

```bash
[root@server ~]# cat /etc/docker/daemon.json
{
"registry-mirrors": ["https://8m0vweth.mirror.aliyuncs.com"],
"insecure-registries": ["0.0.0.0/0"]
}
```


**4. 配置Docker存储驱动**
> 本次实验跳过此步骤

OverlayFS是一个新一代的联合文件系统，类似于AUFS，但速度更快，实现更简单。Docker为OverlayFS提供了两个存储驱动程序:旧版的overlay，新版的overlay2(更稳定)。

先决条件：
- overlay2: Linux内核版本4.0或更高版本，或使用内核版本3.10.0-514+的RHEL或CentOS。
- overlay: 主机Linux内核版本3.18+
- 支持的磁盘文件系统
    - ext4(仅限RHEL 7.1)
    - xfs(RHEL7.2及更高版本)，需要启用d_type=true。 >具体详情参考 Docker Use the OverlayFS storage driver

编辑/etc/docker/daemon.json加入以下内容
```json
{
"storage-driver": "overlay2",
"storage-opts": ["overlay2.override_kernel_check=true"]
}
```

**5. 配置日志驱动**

容器在运行时会产生大量日志文件，很容易占满磁盘空间。通过配置日志驱动来限制文件大小与文件的数量。 >限制单个日志文件为100M,最多产生3个日志文件

```json
{
"log-driver": "json-file",
"log-opts": {
    "max-size": "100m",
    "max-file": "3"
    }
}
```

## 5、harbor镜像库安装
> 安装harbor是用于离线安装rancher组件、K8S组件时的镜像拉取，也可以用于应用部署时自定义镜像存储

Harbor 是一个企业级的 Docker Registry，可以实现images的私有存储和日志统计权限控制等功能，并支持创建多项目(Harbor 提出的概念)，基于官方Registry实现。 通过地址:[https://github.com/goharbor/harbor/releases/](https://github.com/goharbor/harbor/releases/)可以下载最新的版本。官方提供了三种版本:在线版、离线版、OVA虚拟镜像版。

在线安装:安装程序从Docker镜像仓库下载Harbour相关映像。因此，安装程序的尺寸非常小。
离线安装:主机没有Internet连接时使用此安装程序镜像安装。安装程序包含所有镜像，因此压缩包较大。
详细过程参考[harbor安装](https://github.com/goharbor/harbor/blob/master/docs/installation_guide.md)

**1. 配置https**

1.1  生成自建ca 证书
默认在/data/cert/
```
[root@harbor ~]#cd /data/cert/
[root@harbor cert]#openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt -subj "/CN=kago.site"
```
1.2  生成请求   
```bash
[root@harbor cert]#openssl req -newkey rsa:4096 -nodes -sha256 -keyout harbor.kago.site.key -out harbor.kago.site.csr -subj "/CN=harbor.kago.site"
```

1.3 证书签署   
```bash
[root@harbor cert]#openssl x509 -req -days 365 -in harbor.kago.site.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out harbor.kago.site.crt
```

1.4 更改配置
```
[root@harbor harbor]#vim harbor.cfg
hostname = harbor.kago.site:443
ui_url_protocol = https
ssl_cert = /data/cert/harbor.kago.site.crt
ssl_cert_key = /data/cert/harbor.kago.site.key
```
** 2. 执行安装**
```bash
[root@harbor cert]#cd /opt/harbor/
[root@harbor harbor]#sh install.sh
```


## 6、离线环境镜像准备
在线安装rancher虽然方便，但需要从互联网拉取诸多镜像，在独立内网环境下不适用，此处记录离线环境下安装rancher。
在联网环境下获取镜像后，以便离线使用
1. 所需镜像列表
```bash
[root@harbor opt]#cat rancher-images.txt
busybox
minio/minio:RELEASE.2018-05-25T19-49-13Z
rancher/alertmanager-helper:v0.0.2
rancher/calico-cni:v3.1.1
rancher/calico-cni:v3.1.3
rancher/calico-ctl:v2.0.0
rancher/calico-node:v3.1.1
rancher/calico-node:v3.1.3
rancher/cluster-proportional-autoscaler-amd64:1.0.0
rancher/coreos-etcd:v3.1.12
rancher/coreos-etcd:v3.2.18
rancher/coreos-etcd:v3.2.24
rancher/coreos-flannel-cni:v0.2.0
rancher/coreos-flannel-cni:v0.3.0
rancher/coreos-flannel:v0.10.0
rancher/coreos-flannel:v0.9.1
rancher/docker-elasticsearch-kubernetes:5.6.2
rancher/fluentd-helper:v0.1.2
rancher/fluentd:v0.1.10
rancher/hyperkube:v1.10.5-rancher1
rancher/hyperkube:v1.11.3-rancher1
rancher/hyperkube:v1.12.0-rancher1
rancher/hyperkube:v1.9.7-rancher2
rancher/jenkins-jnlp-slave:3.10-1-alpine
rancher/jenkins-plugins-docker:17.12
rancher/k8s-dns-dnsmasq-nanny-amd64:1.14.10
rancher/k8s-dns-dnsmasq-nanny-amd64:1.14.13
rancher/k8s-dns-dnsmasq-nanny-amd64:1.14.7
rancher/k8s-dns-dnsmasq-nanny-amd64:1.14.8
rancher/k8s-dns-kube-dns-amd64:1.14.10
rancher/k8s-dns-kube-dns-amd64:1.14.13
rancher/k8s-dns-kube-dns-amd64:1.14.7
rancher/k8s-dns-kube-dns-amd64:1.14.8
rancher/k8s-dns-sidecar-amd64:1.14.10
rancher/k8s-dns-sidecar-amd64:1.14.13
rancher/k8s-dns-sidecar-amd64:1.14.7
rancher/k8s-dns-sidecar-amd64:1.14.8
rancher/kibana:5.6.4
rancher/log-aggregator:v0.1.3
rancher/metrics-server-amd64:v0.2.1
rancher/metrics-server-amd64:v0.3.1
rancher/nginx-ingress-controller-defaultbackend:1.4
rancher/nginx-ingress-controller:0.16.2-rancher1
rancher/pause-amd64:3.0
rancher/pause-amd64:3.1
rancher/pipeline-jenkins-server:v0.1.0
rancher/pipeline-tools:v0.1.0
rancher/prom-alertmanager:v0.15.2
rancher/rke-tools:v0.1.13
rancher/rke-tools:v0.1.15
registry:2
rancher/rancher:v2.1.1
rancher/rancher-agent:v2.1.1
```
2. 拉取保存脚本
```bash
[root@harbor opt]#cat rancher-save-images.sh
#!/bin/bash
list="rancher-images.txt"
images="rancher-images.tar.gz"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--images)
        images="$2"
        shift # past argument
        shift # past value
        ;;
        -l|--image-list)
        list="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        help="true"
        shift
        ;;
    esac
done

usage () {
    echo "USAGE: $0 [--image-list rancher-images.txt] [--images rancher-images.tar.gz]"
    echo "  [-l|--images-list path] text file with list of images. 1 per line."
    echo "  [-l|--images path] tar.gz generated by docker save."
    echo "  [-h|--help] Usage message"
}

if [[ $help ]]; then
    usage
    exit 0
fi

set -e -x

for i in $(cat ${list}); do
    docker pull ${i}
done

docker save $(cat ${list} | tr '\n' ' ') | gzip -c > ${images}
```

3. 项目创建
登录harbor.kago.site，创建公开项目rancher、minio


4. 镜像上传
```bash
[root@harbor opt]#cat rancher-load-images.sh
#!/bin/bash
list="rancher-images.txt"
images="rancher-images.tar.gz"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--registry)
        reg="$2"
        shift # past argument
        shift # past value
        ;;
        -l|--image-list)
        list="$2"
        shift # past argument
        shift # past value
        ;;
        -i|--images)
        images="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        help="true"
        shift
        ;;
    esac
done

usage () {
    echo "USAGE: $0 [--image-list rancher-images.txt] [--images rancher-images.tar.gz] --registry my.registry.com:5000"
    echo "  [-l|--images-list path] text file with list of images. 1 per line."
    echo "  [-l|--images path] tar.gz generated by docker save."
    echo "  [-r|--registry registry:port] target private registry:port."
    echo "  [-h|--help] Usage message"
}

if [[ -z $reg ]]; then
    usage
    exit 1
fi
if [[ $help ]]; then
    usage
    exit 0
fi

set -e -x

docker load --input ${images}

for i in $(cat ${list}); do
    docker tag ${i} ${reg}/${i}
    docker push ${reg}/${i}
done

[root@harbor opt]#docker login harbor.kago.site
[root@harbor opt]#sh rancher-load-images.sh -l ./rancher-images.txt -r harbor.kago.site
```



## 7、安装rancher-server
1. 启动rancher-server
```bash
[root@server opt]#docker run -d --restart=unless-stopped   -p 80:80 -p 443:443   -v /root/var/log/auditlog:/var/log/auditlog   -e AUDIT_LEVEL=3   -e AUDIT_LOG_PATH=/var/log/auditlog/rancher-api-audit.log   -e AUDIT_LOG_MAXAGE=20   -e AUDIT_LOG_MAXBACKUP=20   -e AUDIT_LOG_MAXSIZE=100   harbor.kago.site/rancher/rancher:v2.1.1
[root@server ~]# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                                      NAMES
8dc861f595b4        5370bbde1a1b        "entrypoint.sh"     7 hours ago         Up 6 hours          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   stupefied_austin
```

2. 浏览器登录rancher-server
- 设置密码
- 设置url
> 重置管理员密码：docker exec -ti <container_id> reset-password

## 8、K8S集群安装
1. 修改系统镜像库地址

使用浏览器登录rancher-server，点击“全局配置”--“系统设置”，找到“system-default-registry"，点击编辑，设置为harbor镜像库地址。
![](/images/posts/rancher/2018-11-26_112843.png)
![](/images/posts/rancher/2018-11-26_112911.png)

2. 添加集群   
![](/images/posts/rancher/2018-11-26_112242.png)

3. 选择自定义
![](/images/posts/rancher/2018-11-26_112436.png)

4. 选择组件信息  
![](/images/posts/rancher/2018-11-26_112549.png)
>当有内外网时，点击“高级选型”添加主机内外网地址

5. 选择主机角色
![](/images/posts/rancher/2018-11-26_112702.png)
> 主机角色中的etcd为k8s中数据库，controller包含k8s的master组件（apiserver、controller manager、schedule），worker包含kubelet、kube-proxy

6. 登录主机执行命令
拷贝给出的命令，登录目标主机执行命令，片刻后会自动注册至rancher-server

7. 注册成功
![](/images/posts/rancher/2018-11-26_113449.png)


## 9、命令行工具
1.  kubectl   
点击“集群”，点击“kubeconfig”复制文件到需要运行kubectl的主机~/.kube/config

2. rancher-cli   
登录rancher-server，点击用户头像，选择“api&ksys”，点击添加key，填写描述信息，选择有效时长，保存key信息，复制token
在安装有rancher-cli的windows cmd中运行：   
rancher login https://rancher-server-ip  --token <token\>
![](/images/posts/rancher/2018-11-26_133849.png)

