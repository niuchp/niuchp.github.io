---
layout: post
title: Rancher高可用部署
categories: [rancher, kubernetes]
description: 利用Helm部署高可用的Rancher-Server
keywords: rancher, kubernetes,HA
---

> 前一篇博客[ "CentOS7安装Rancher2.x" ](https://kago.site/2018/11/26/install-rancher/)分享可如何部署单节点的 Rancher-Server。在生产环境部署时，需要考虑到 Rancher-Server 的可用性，单实例部署时，当 Rancher-Server 节点出现故障导致服务不可用时（ rancher-server 故障不会影响运行的 k8s 集群及其业务容器），将不能通过 web-ui 进行操作。本文通过参考[官方文档](https://www.cnrancher.com/docs/rancher/v2.x/cn/installation/server-installation/ha-install/helm-rancher/)分享搭建高可用 Rancher-Server 的过程。



## 1、说明

### 1.1、架构说明

Rancher-Server 的高可用部署，实则是利用 kubernetes 的 deployment 实现，利用 rke 工具，部署三节点 kubernetes 集群（每个节点都运行 etcd、kube-master、kube-worker），使用helm 安装 Rancher-Server，Rancher-Server 即为 kubernetes 中的应用服务，由集群提供高可用实现。前端可配置负载均衡器或软件负载均衡如 nginx 或 ingress，安装完成后 Rancher-Server 会自动纳管 rke 安装的本地 kubernetes 集群。

![rancher-ha架构](/images/posts/rancher-ha/2018-12-10_111310.png)

### 1.2、环境说明

- 操作系统：CentOS7.2
- OS内核：3.10.0 (使用Overlay2需要升级内核至4.x）
- Rancher:2.1.3
- Docker: 17.03
- 集群IP地址划分：

|role|hostname|IP|
|-------|---------|--------|
|rancher-server|server1|192.168.31.10|
|rancher-server|server2|192.168.31.11|
|rancher-server|server3|192.168.31.12|
|worker|node1|192.168.31.20|
|worker|node2|192.168.31.21|
|worker|node3|192.168.31.22|
|registry|harbor.kago.site|192.168.31.65|

参考[ "CentOS7安装Rancher2.x" ](https://kago.site/2018/11/26/install-rancher/)要求各个服务器满足如下要求：

1. harbor镜像库：
    - 安装完成
    - 上传 rancher 所需镜像
2. Rancher-Server节点：
    - 各节点安装 docker
    - 信任 harbor 镜像库，并完成登录
    - 新建 rancher 用户
    - 各节点 rancher 用户可 ssh 免密钥登录
    - openssh 版本在 6.7 以上  
3. worker节点：  
    - 各节点安装 docker
    - 信任 harbor 镜像库，并完成登录

### 1.3、软件准备

- rke

1. 点击[下载rke-linux-amd64](https://www.cnrancher.com/download/rke/rke_linux-amd64)

2. 复制命令到PATH
```bash
[root@server1 ~]# chmod +x rke_linux_amd64
[root@server1 ~]# cp rke_linux_amd64 /usr/local/bin/
[root@server1 ~]# ln -s /usr/local/bin/rke_linux_amd64 /usr/bin/rke
```

- helm

1. 点击[下载helm-linux.tar.gz](https://www.cnrancher.com/download/helm/helm-linux.tar.gz)

2. 解压文件并复制到PATH
```bash
[root@server1 ~]# tar -zxf helm-linux.tar.gz
[root@server1 ~]# chmod +x linux-amd64/helm
[root@server1 ~]# cp linux-amd64/helm /usr/bin
```
3. 获取tiller镜像
```bash
[root@server1 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.12
[root@server1 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.12 harbor.kago.site/google_containers/tiller:v2.12
[root@server1 ~]# docker push harbor.kago.site/google_containers/tiller:v2.12
```

- kubectl

1. 点击[下载kubectl](https://www.cnrancher.com/download/kubectl/kubectl_amd64-linux)

2. 复制到PATH
```bash
[root@server1 ~]# cp kubectl_amd64-linux /usr/local/bin
[root@server1 ~]# chmod +x /usr/local/bin/kubectl_amd64-linux
[root@server1 ~]# ln -s /usr/local/bin/kubectl_amd64-linux /usr/bin/kubectl
```

## 2、RKE安装 K8S 集群

> 该集群仅用于运行 Rancher-Server，CentOS 环境下使用非 root 用户安装（本案例使用 rancher 用户）。

### 2.1、创建配置文件rancher-cluster.yml

```yml
nodes:
  - address: 192.168.31.10
    user: rancher
    role: [controlplane,worker,etcd]
  - address: 192.168.31.11
    user: rancher
    role: [controlplane,worker,etcd]
  - address: 192.168.31.12
    user: rancher
    role: [controlplane,worker,etcd]

private_registries:
- url: harbor.kago.site
user: admin
password: "xxxxxxxxx"
is_default: true

services:
  etcd:
    snapshot: true
    creation: 6h
    retention: 24h
```

### 2.2、执行安装
```bash
[rancher@server1 ~]$ sudo rke up --config ./rancher-cluster.yml
```
当提示“Finished builled Kubernetes cluster successfully”说明安装成功,并生当前目录生成 kube_config_rancher-cluster.yml 文件。

### 2.3、查看集群状态
```bash
[root@server1 ~]# mkdir ~/.kube
[root@server1 ~]# cp kube_config_rancher-cluster.yml ~/.kube/config
[root@server1 ~]# kubectl get node
```

## 3、安装helm server

### 3.1、配置 helm 客户端访问权限

Helm在集群上安装tiller服务以管理charts. 由于RKE默认启用RBAC, 因此我们需要使用kubectl来创建一个serviceaccount，clusterrolebinding才能让tiller具有部署到集群的权限。

- 在kube-system命名空间中创建ServiceAccount；
- 创建ClusterRoleBinding以授予tiller帐户对集群的访问权限
- helm初始化tiller服务

```bash
[root@server1 ~]# kubectl -n kube-system create serviceaccount tiller
[root@server1 ~]# kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
```
### 3.2、添加镜像仓库密钥
1. 生成密钥
```bash
[root@server1 ~]# kubectl -n kube-system create secret docker-registry regSecret --docker-server="harbor.kago.site" --docker-username=admin --docker-password=xxxxxxxx --docker-email=niuchp@126.com
```
2. 打patch
```bash
[root@server1 ~]# kubectl -n kube-system patch serviceaccounts tiller -p '{"imagePullSecrets": [{"name": "regSecret"}]}'
```

### 3.3、安装helm server
```bash
[root@server1 ~]# helm init --service-account tiller --tiller-image harbor.kago.site/google_containers/tiller:v2.12 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```

### 3.4、添加chart仓库
```bash
[root@server1 ~]# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
```

## 4、安装 Rancher Server
### 4.1、安装cert-manager
```bash
[root@server1 ~]# helm install stable/cert-manager  --name cert-manager --namespace kube-system
```
- 离线环境：

1. 在能联网的机器上获取chart
```bash
[root@server1 ~]# helm fetch stable/cert-manager
```
2. 上传chart后修改配置
```bash
[root@server1 ~]# helm template ./cert-manager-v0.8.0.tgz --output-dir . --name cert-manager --namespace kube-system --set image.repository=harbor.kago.site.com/jetstack/cert-manager-controller
```

3. 运行
```bash
[root@server1 ~]# kubectl apply -n kube-system - R -f ./cert-manager
```

### 4.2、安装rancher server
```bash
[root@server1 ~]# helm install rancher-stable/rancher --name rancher --namespace cattle-system --set hostname=rancher.kago.site
```
> 默认情况下，Rancher会自动生成CA根证书并使用cert-manager颁发证书，因此，这里设置了 hostname=rancher.kago.site，后续只能通过域名访问UI

- 离线环境：

1. 在能联网的机器上获取chart
```bash
[root@server1 ~]# helm fetch rancher-stable/rancher
```
2. 上传chart后修改配置
```bash
[root@server1 ~]# helm template ./rancher-2018.10.2.tgz --output-dir . --name rancher --namespace cattle-system --set hostname=rancher.kago.site --set rancherImage=harbor.kago.site/rancher/rancher
```

3. 运行
```bash
[root@server1 ~]# kubectl create namespace cattle-system
[root@server1 ~]# kubectl apply -n cattle-system -R -f ./rancher
```


## 5、为Agent Pod添加主机别名

如果你没有内部DNS服务器而是通过添加/etc/hosts主机别名的方式指定的Rancher server域名，那么不管通过哪种方式(自定义、导入、Host驱动等)创建K8S集群，K8S集群运行起来之后，因为cattle-cluster-agent Pod和cattle-node-agent无法通过DNS记录找到Rancher server,最终导致无法通信。

可以通过给cattle-cluster-agent Pod和cattle-node-agent添加主机别名(/etc/hosts)，让其可以正常通信(前提是IP地址可以互通)。

> 注意：替换以下命令中的域名和IP

### 5.1、cattle-cluster-agent pod
```bash
[root@server1 ~]# kubectl -n cattle-system patch  deployments cattle-cluster-agent --patch '{
    "spec": {
        "template": {
            "spec": {
                "hostAliases": [
                    {
                        "hostnames":
                        [
                            "rancher.kago.site"
                        ],
                            "ip": "192.168.31.10"
                    }
                ]
            }
        }
    }
}'
```

### 5.2、cattle-node-agent pod
```bash
[root@server1 ~]# kubectl -n cattle-system patch  daemonsets cattle-node-agent --patch '{
    "spec": {
        "template": {
            "spec": {
                "hostAliases": [
                    {
                        "hostnames":
                        [
                            "rancher.kago.site"
                        ],
                            "ip": "192.168.31.10"
                    }
                ]
            }
        }
    }
}'
```