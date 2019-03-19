# SaltStack自动化部署HA-Kubernetes
- 本项目在GitHub上，会不定期更新，大家也可以提交ISSUE，地址为：`https://github.com/skymyyang/salt-k8s-ha`
- SaltStack自动化部署 `Kubernetes v1.12.5` 版本（支持HA、TLS双向认证、RBAC授权、Flannel网络、ETCD集群、Kuber-Proxy使用LVS等）。
- SaltStack自动化部署 `Kubernetes v1.13.4` 版本，请切换到 `1.13-Release` 分支。

## 版本明细：Release-v1.12.5
- 测试通过系统：CentOS 7.6
- salt-ssh:     salt-ssh 2018.3.3 (Oxygen)
- Kubernetes：  v1.12.5
- Etcd:         v3.3.10
- Docker:       docker-ce-18.06.0.ce-3.el7
- Flannel：     v0.10.0
- CNI-Plugins： v0.7.0
建议部署节点：最少三个Master节点，请配置好主机名解析（必备）。以下是最小配置，否则可能不成功。

IP地址 | Hostname | 最小配置 | Kernel Version
---|--- | --- | --- |
192.168.150.141 | linux-node1 | Centos7.6 2G 2CPU | 4.18.16-1.el7.elrepo.x86_64
192.168.150.142 | linux-node2 | Centos7.6 2G 2CPU | 4.18.16-1.el7.elrepo.x86_64
192.168.150.143 | linux-node3 | Centos7.6 2G 2CPU | 4.18.16-1.el7.elrepo.x86_64
192.168.150.144 | linux-node4 | Centos7.6 1G 1CPU | 4.18.16-1.el7.elrepo.x86_64

## 架构介绍
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.12.5，保证稳定性。
5. 使用HaProxy和keepalived来保证集群的高可用。

## 技术交流QQ群（加群请备注来源于Github）：
- Docker&Kubernetes：796163694

- 本教程的来源于以下教程而生成，在此特别感谢两位作者。

  和我一步步部署 kubernetes 集群   `https://github.com/opsnull/follow-me-install-kubernetes-cluster`

  SaltStack自动化部署Kubernetes    `https://github.com/unixhot/salt-kubernetes`

## 案例架构图

  ![架构图](https://skymyyang.github.io/img/k8s2.png)

## 0.系统初始化(必备)

1. 设置主机名！！！

```bash
[root@linux-node1 ~]# cat /etc/hostname
linux-node1

[root@linux-node2 ~]# cat /etc/hostname
linux-node2

[root@linux-node3 ~]# cat /etc/hostname
linux-node3

[root@linux-node4 ~]# cat /etc/hostname
linux-node4
```

2. 设置/etc/hosts保证主机名能够解析

```bash
[root@linux-node1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.150.141 linux-node1
192.168.150.142 linux-node2
192.168.150.143 linux-node3
192.168.150.144 linux-node4
```

3. 关闭SELinux和防火墙以及NetworkManager

```bash
   systemctl disable --now firewalld NetworkManager
   setenforce 0
   sed -ri '/^[^#]*SELINUX=/s#=.+$#=disabled#' /etc/selinux/config
```

4. 升级内核并且优化内核参数

   <table border="0">
       <tr>
           <td><a href="docs/update-kernel.md">升级内核</a></td>
       </tr>
   </table>

5. 以上必备条件必须严格检查，否则，一定不会部署成功！

## 1.设置部署节点到其它所有节点的SSH免密码登录（包括本机）
```bash
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
[root@linux-node1 ~]# ssh-copy-id linux-node4
[root@linux-node1 ~]# scp /etc/hosts linux-node2:/etc/
[root@linux-node1 ~]# scp /etc/hosts linux-node3:/etc/
[root@linux-node1 ~]# scp /etc/hosts linux-node4:/etc/
```

## 2.安装Salt-SSH并克隆本项目代码。

2.1 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）
```bash
[root@linux-node1 ~]# yum install -y https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
[root@linux-node1 ~]# sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
[root@linux-node1 ~]# yum install -y salt-ssh git unzip
```

2.2 获取本项目代码，并放置在 `/srv` 目录

```bash
[root@linux-node1 ~]# git clone https://github.com/skymyyang/salt-k8s-ha.git
[root@linux-node1 ~]# cd salt-k8s-ha/
[root@linux-node1 ~]# mv * /srv/
[root@linux-node1 srv]# /bin/cp /srv/roster /etc/salt/roster
[root@linux-node1 srv]# /bin/cp /srv/master /etc/salt/master
```

2.4 下载二进制文件，也可以自行官方下载，为了方便国内用户访问，请在百度云盘下载,下载k8s-v1.12.5-auto.zip。
下载完成后，将文件移动到 `/srv/salt/k8s/` 目录下，并解压，注意是 `files` 目录在 `/srv/salt/k8s/`目录下。
Kubernetes二进制文件下载地址： `https://pan.baidu.com/s/1Ag2ocpVmkg-uEoV13A7HFw`

```bash
[root@linux-node1 ~]# cd /srv/salt/k8s/
[root@linux-node1 k8s]# unzip k8s-v1.12.5-auto.zip
[root@linux-node1 k8s]# rm -f k8s-v1.12.5-auto.zip
[root@linux-node1 k8s]# ls -l files/
total 0
drwxr-xr-x 2 root root  94 Jan 18 19:19 cfssl-1.2
drwxr-xr-x 2 root root 195 Jan 18 19:19 cni-plugins-amd64-v0.7.4
drwxr-xr-x 3 root root 123 Jan 18 19:19 etcd-v3.3.10-linux-amd64
drwxr-xr-x 2 root root  47 Jan 18 19:19 flannel-v0.10.0-linux-amd64
drwxr-xr-x 3 root root  17 Jan 18 19:19 k8s-v1.12.5

```

## 3.Salt SSH管理的机器以及角色分配

- k8s-role: 用来设置K8S的角色
- etcd-role: 用来设置etcd的角色，如果只需要部署一个etcd，只需要在一台机器上设置即可
- etcd-name: 如果对一台机器设置了etcd-role就必须设置etcd-name

```yaml
[root@linux-node1 ~]# vim /etc/salt/roster
linux-node1:
  host: 192.168.150.141
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node1

linux-node2:
  host: 192.168.150.142
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node2

linux-node3:
  host: 192.168.150.143
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node3

linux-node4:
  host: 192.168.150.144
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
```

## 4.修改对应的配置参数，本项目使用Salt Pillar保存配置
```bash
[root@k8s-m1 ~]# vim /srv/pillar/k8s.sls
#设置Master的IP地址(必须修改)
MASTER_IP_M1: "192.168.150.141"
MASTER_IP_M2: "192.168.150.142"
MASTER_IP_M3: "192.168.150.143"
#设置Master的HOSTNAME完整的FQDN名称(必须修改)
MASTER_H1: "linux-node1"
MASTER_H2: "linux-node2"
MASTER_H3: "linux-node3"

#设置ETCD集群访问地址（必须修改）
ETCD_ENDPOINTS: "https://192.168.150.141:2379,https://192.168.150.142:2379,https://192.168.150.143:2379"

FLANNEL_ETCD_PREFIX: "/kubernetes/network"

#设置ETCD集群初始化列表（必须修改）
ETCD_CLUSTER: "etcd-node1=https://192.168.150.141:2380,etcd-node2=https://192.168.150.142:2380,etcd-node3=https://192.168.150.143:2380"

#通过Grains FQDN自动获取本机IP地址，请注意保证主机名解析到本机IP地址
NODE_IP: {{ grains['fqdn_ip4'][0] }}
HOST_NAME: {{ grains['fqdn'] }}
#设置BOOTSTARP的TOKEN，可以自己生成
BOOTSTRAP_TOKEN: "be8dad.da8a699a46edc482"
TOKEN_ID: "be8dad"
TOKEN_SECRET: "da8a699a46edc482"
ENCRYPTION_KEY: "8eVtmpUpYjMvH8wKZtKCwQPqYRqM14yvtXPLJdhu0gA="
#配置Service IP地址段
SERVICE_CIDR: "10.1.0.0/16"

#Kubernetes服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_KUBERNETES_SVC_IP: "10.1.0.1"

#Kubernetes DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP: "10.1.0.2"

#设置Node Port的端口范围
NODE_PORT_RANGE: "20000-40000"

#设置POD的IP地址段
POD_CIDR: "10.2.0.0/16"

#设置集群的DNS域名
CLUSTER_DNS_DOMAIN: "cluster.local."

#设置Docker Registry地址
#DOCKER_REGISTRY: "https://192.168.150.135:5000"

#设置Master的VIP地址(必须修改)
MASTER_VIP: "192.168.150.253"

#设置网卡名称
VIP_IF: "ens32"


```

## 5.执行SaltStack状态

5.1 测试Salt SSH联通性

```bash
[root@k8s-m1 ~]# salt-ssh '*' test.ping
```
执行高级状态，会根据定义的角色再对应的机器部署对应的服务

5.2 部署Etcd，由于Etcd是基础组建，需要先部署，目标为部署etcd的节点。

增加etcd参数的优化。

- `--auto-compaction-retention`
由于ETCD数据存储多版本数据，随着写入的主键增加历史版本需要定时清理，默认的历史数据是不会清理的，数据达到2G就不能写入，必须要清理压缩历史数据才能继续写入;所以根据业务需求，在上生产环境之前就提前确定，历史数据多长时间压缩一次;推荐一小时压缩一次数据这样可以极大的保证集群稳定，减少内存和磁盘占用

- `--max-request-bytes` etcd Raft消息最大字节数，ETCD默认该值为1.5M; 但是很多业务场景发现同步数据的时候1.5M完全没法满足要求，所以提前确定初始值很重要;由于1.5M导致我们线上的业务无法写入元数据的问题，我们紧急升级之后把该值修改为默认32M，但是官方推荐的是10M，大家可以根据业务情况自己调整

- `--quota-backend-bytes` ETCD db数据大小，默认是2G，当数据达到2G的时候就不允许写入，必须对历史数据进行压缩才能继续写入;参加1里面说的，我们启动的时候就应该提前确定大小，官方推荐是8G，这里我们也使用8G的配置

```bash
[root@linux-node1 ~]# salt-ssh -L 'linux-node1,linux-node2,linux-node3' state.sls k8s.etcd
```
注：如果执行失败，新手建议推到重来，请检查各个节点的主机名解析是否正确（监听的IP地址依赖主机名解析）。

5.3 部署K8S集群
```bash
[root@linux-node1 ~]# salt-ssh '*' state.highstate
```
由于包比较大，这里执行时间较长，5分钟+，喝杯咖啡休息一下，如果执行有失败可以再次执行即可！

## 6.测试Kubernetes安装
```
#先验证etcd
[root@linux-node1 ~]# source /etc/profile
[root@linux-node1 ~]# etcdctl --endpoints=https://192.168.150.141:2379 \
  --ca-file=/opt/kubernetes/ssl/ca.pem \
  --cert-file=/opt/kubernetes/ssl/etcd.pem \
  --key-file=/opt/kubernetes/ssl/etcd-key.pem cluster-health
[root@linux-node1 ~]# etcdctl --endpoints=https://192.168.150.141:2379 \
  --ca-file=/opt/kubernetes/ssl/ca.pem \
  --cert-file=/opt/kubernetes/ssl/etcd.pem \
  --key-file=/opt/kubernetes/ssl/etcd-key.pem member list
[root@linux-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-2               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}  
[root@k8s-m1 ~]# kubectl get node
NAME          STATUS   ROLES    AGE   VERSION
linux-node1   Ready    master   14m   v1.12.5
linux-node2   Ready    master   24m   v1.12.5
linux-node3   Ready    master   24m   v1.12.5
linux-node4   Ready    node     30m   v1.12.5
```
## 7.测试Kubernetes集群和Flannel网络

```
[root@linux-node1 ~]# kubectl create deployment nginx --image=nginx:alpine
deployment.apps/nginx created
需要等待拉取镜像，可能稍有的慢，请等待。
[root@linux-node1 ~]# kubectl get pod
NAME                     READY   STATUS    RESTARTS   AGE
nginx-54458cd494-8fj47   1/1     Running   0          13s

[root@linux-node1 ~]# kubectl get pod -o wide
NAME                     READY   STATUS    RESTARTS   AGE    IP          NODE          NOMINATED NODE   READINESS GATES
nginx-54458cd494-8fj47   1/1     Running   0          111s   10.2.70.3   linux-node1   <none>           <none>



测试联通性
[root@linux-node1 ~]# ping -c 1 10.2.70.3
PING 10.2.69.2 (10.2.69.2) 56(84) bytes of data.
64 bytes from 10.2.69.2: icmp_seq=1 ttl=61 time=2.02 ms

--- 10.2.69.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 2.028/2.028/2.028/0.000 ms

[root@linux-node1 ~]# curl --head http://10.2.70.3
HTTP/1.1 200 OK
Server: nginx/1.15.8
Date: Wed, 27 Feb 2019 09:52:48 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Thu, 31 Jan 2019 23:32:11 GMT
Connection: keep-alive
ETag: "5c53857b-264"
Accept-Ranges: bytes

测试扩容，将Nginx应用的Pod副本数量拓展到2个节点
[root@linux-node1 ~]# kubectl scale deployment nginx --replicas=2
deployment.extensions/nginx scaled

[root@linux-node1 ~]# kubectl get pod
NAME                     READY   STATUS    RESTARTS   AGE
nginx-54458cd494-8fj47   1/1     Running   0          5m4s
nginx-54458cd494-qzhpf   1/1     Running   0          17s
```

## 8.如何新增Kubernetes节点

- 1.设置SSH无密码登录，并且在 `/etc/hosts` 中继续增加对应的解析。确保所有节点都能解析。
- 2.在 `/etc/salt/roster` 里面，增加对应的机器。
- 3.执行SaltStack状态 `salt-ssh '*' state.highstate`

```Bash
[root@linux-node5 ~]# vim /etc/salt/roster
linux-node5:
  host: 192.168.150.145
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
[root@linux-node1 ~]# salt-ssh 'linux-node5' state.highstate
```

## 9.下一步要做什么？

你可以安装Kubernetes必备的插件
<table border="0">
    <tr>
        <td><strong>必备插件</strong></td>
        <td><a href="docs/coredns.md">1.CoreDNS部署</a></td>
        <td><a href="docs/dashboard.md">2.Dashboard部署</a></td>
        <td><a href="docs/metrics-server.md">3.Metrics Server</a></td>
        <td><a href="docs/ingress-nginx.md">4.Ingress-nginx部署</a></td>
        <td><a href="docs/ingress.md">5.Ingress扩展</a></td>
        <td><a href="docs/metallb.md">6.MetalLB</a></td>
    </tr>
</table>

为Master节点打上污点，让POD尽可能的不要调度到Master节点上。

关于污点的说明大家可自行百度。

```bash
kubectl describe node linux-node1
kubectl taint node k8s-m1 node-role.kubernetes.io/master=linux-node1:PreferNoSchedule
kubectl taint node k8s-m2 node-role.kubernetes.io/master=linux-node2:PreferNoSchedule
kubectl taint node k8s-m3 node-role.kubernetes.io/master=linux-node3:PreferNoSchedule
```

## 10.已知的错误。

此错误暂未发现影响

```bash
[root@linux-node2 ~]# journalctl -u kube-proxy
......
Feb 21 12:02:22 linux-node2 kube-proxy[40633]: I0221 12:02:22.106696   40633 server_others.go:216] Tearing down inactive rules.
Feb 21 12:02:22 linux-node2 kube-proxy[40633]: E0221 12:02:22.195324   40633 proxier.go:430] Failed to execute iptables-restore for nat: exit status 1 (iptables-restore: line 7 failed
Feb 21 12:02:22 linux-node2 kube-proxy[40633]: )
......
```
如果有洁癖的，忍受不了这种错误的，我们可以把kube-proxy按照daemonset的方式部署;按照这种方式部署的话要先停用二进制安装的kube-proxy。

PS:这里配置不一样的话需要修改yaml文件。

```bash
[root@linux-node1 ~]# systemctl disable kube-proxy
[root@linux-node1 ~]# systemctl stop kube-proxy
[root@linux-node1 ~]# kubectl apply -f /srv/addons/kube-proxy/kube-proxy.yml
[root@linux-node1 ~]# kubectl get pod -n kube-system
NAME                      READY   STATUS    RESTARTS   AGE
coredns-cd7f66fdc-fxvx6   1/1     Running   2          18h
coredns-cd7f66fdc-ldjnh   1/1     Running   2          18h
kube-proxy-czxj9          1/1     Running   2          16h
kube-proxy-pjpt5          1/1     Running   2          16h
kube-proxy-wpfrh          1/1     Running   2          16h
kube-proxy-zgg6t          1/1     Running   2          16h
```
#### 如果你觉得这个项目不错，欢迎各位打赏，你的打赏是对我们的认可，是我们的动力。

![支付宝支付](https://skymyyang.github.io/img/zfb3.png)

![微信支付](https://skymyyang.github.io/img/wx1.png)
