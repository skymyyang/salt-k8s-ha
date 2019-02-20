# SaltStack自动化部署HA-Kubernetes
- SaltStack自动化部署Kubernetes v1.12.5版本（支持HA、TLS双向认证、RBAC授权、Flannel网络、ETCD集群、Kuber-Proxy使用LVS等）。

## 版本明细：Release-v1.12.5
- 测试通过系统：CentOS 7.6
- salt-ssh:     salt-ssh 2018.3.3 (Oxygen)
- Kubernetes：  v1.12.5
- Etcd:         v3.3.10
- Docker:       docker-ce-18.06.0.ce-3.el7
- Flannel：     v0.10.0
- CNI-Plugins： v0.7.0
建议部署节点：最少三个Master节点，请配置好主机名解析（必备）。

## 架构介绍
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.12.5，保证稳定性。
5. 使用HaProxy和keepalived来保证集群的高可用。

## 技术交流QQ群（加群请备注来源于Github）：
- Docker&Kubernetes：796163694

- 关于本帖子上的手动部署，我还没有进行验证和修改，还只能适用于原作者的1.10.3版本；感兴趣的同学可以看一下两位作者的教程。

- 本教程的来源于以下教程而生成，在此特别感谢两位作者。

  和我一步步部署 kubernetes 集群   https://github.com/opsnull/follow-me-install-kubernetes-cluster

  SaltStack自动化部署Kubernetes    https://github.com/unixhot/salt-kubernetes

# 使用手册
<table border="0">
    <tr>
        <td><strong>手动部署</strong></td>
        <td><a href="docs/update-kernel.md">1.升级内核</a></td>
        <td><a href="docs/ca.md">2.CA证书制作</a></td>
        <td><a href="docs/etcd-install.md">3.ETCD集群部署</a></td>
        <td><a href="docs/master.md">4.Master节点部署</a></td>
        <td><a href="docs/node.md">5.Node节点部署</a></td>
        <td><a href="docs/flannel.md">6.Flannel部署</a></td>
        <td><a href="docs/app.md">7.应用创建</a></td>
    </tr>
    <tr>
        <td><strong>必备插件</strong></td>
        <td><a href="docs/coredns.md">1.CoreDNS部署</a></td>
        <td><a href="docs/dashboard.md">2.Dashboard部署</a></td>
        <td><a href="docs/heapster.md">3.Heapster部署</a></td>
        <td><a href="docs/ingress.md">4.Ingress部署</a></td>
        <td><a href="https://github.com/unixhot/devops-x">5.CI/CD</a></td>
        <td><a href="docs/helm.md">6.Helm部署</a></td>
    </tr>
</table>


## 案例架构图

  ![架构图](https://skymyyang.github.io/img/k8s-ha.jpg)

## 0.系统初始化(必备)
1. 设置主机名！！！
```
[root@k8s-m1 ~]# cat /etc/hostname 
k8s-m1

[root@k8s-m2 ~]# cat /etc/hostname 
k8s-m2

[root@k8s-m3 ~]# cat /etc/hostname 
k8s-m3

[root@k8s-n1 ~]# cat /etc/hostname 
k8s-n1

```
2. 设置/etc/hosts保证主机名能够解析
```
[root@linux-node1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.18.201 k8s-m1
172.16.18.202 k8s-m2
172.16.18.203 k8s-m3
172.16.18.204 k8s-n1

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
[root@linux-node1 ~]# ssh-copy-id k8s-m1
[root@linux-node1 ~]# ssh-copy-id k8s-m2
[root@linux-node1 ~]# ssh-copy-id k8s-m3
```

## 2.安装Salt-SSH并克隆本项目代码。

2.1 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）
```bash
[root@linux-node1 ~]# yum install https://mirrors.aliyun.com/epel/epel-release-latest-7.noarch.rpm
[root@linux-node1 ~]# yum install https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
[root@linux-node1 ~]# sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
[root@linux-node1 ~]# yum install -y salt-ssh git unzip
```

2.2 获取本项目代码，并放置在/srv目录
```bash
[root@linux-node1 ~]# git clone https://github.com/unixhot/salt-kubernetes.git
[root@linux-node1 ~]# cd salt-kubernetes/
[root@linux-node1 ~]# mv * /srv/
[root@linux-node1 srv]# /bin/cp /srv/roster /etc/salt/roster
[root@linux-node1 srv]# /bin/cp /srv/master /etc/salt/master
```

2.4 下载二进制文件，也可以自行官方下载，为了方便国内用户访问，请在百度云盘下载,下载k8s-v1.12.5-auto.zip。
下载完成后，将文件移动到/srv/salt/k8s/目录下，并解压
Kubernetes二进制文件下载地址： https://pan.baidu.com/s/1Ag2ocpVmkg-uEoV13A7HFw

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
[root@k8s-m1 ~]# vim /etc/salt/roster 
k8s-m1:
  host: 172.16.18.201
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node1

k8s-m2:
  host: 172.16.18.202
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node2

k8s-m3:
  host: 172.16.18.203
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node3
k8s-n1:
  host: 172.16.18.204
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
MASTER_IP_M1: "172.16.18.201"
MASTER_IP_M2: "172.16.18.202"
MASTER_IP_M3: "172.16.18.203"
#设置Master的HOSTNAME完整的FQDN名称(必须修改)
MASTER_H1: "k8s-m1"
MASTER_H2: "k8s-m2"
MASTER_H3: "k8s-m3"

#设置ETCD集群访问地址（必须修改）
ETCD_ENDPOINTS: "https://172.16.18.201:2379,https://172.16.18.202:2379,https://172.16.18.203:2379"

FLANNEL_ETCD_PREFIX: "/kubernetes/network"

#设置ETCD集群初始化列表（必须修改）
ETCD_CLUSTER: "etcd-node1=https://172.16.18.201:2380,etcd-node2=https://172.16.18.202:2380,etcd-node3=https://172.16.18.203:2380"

#通过Grains FQDN自动获取本机IP地址，请注意保证主机名解析到本机IP地址
NODE_IP: {{ grains['fqdn_ip4'][0] }}
HOST_NAME: {{ grains['fqdn'] }}
#设置BOOTSTARP的TOKEN，可以自己生成
BOOTSTRAP_TOKEN: "be8dad.da8a699a46edc482"
TOKEN_ID: "be8dad"
TOKEN_SECRET: "da8a699a46edc482"
ENCRYPTION_KEY: "8eVtmpUpYjMvH8wKZtKCwQPqYRqM14yvtXPLJdhu0gA="
#配置Service IP地址段
SERVICE_CIDR: "10.245.0.0/16"

#Kubernetes服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_KUBERNETES_SVC_IP: "10.245.0.1"

#Kubernetes DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP: "10.245.0.2"

#设置Node Port的端口范围
NODE_PORT_RANGE: "20000-40000"

#设置POD的IP地址段
POD_CIDR: "10.244.0.0/16"

#设置集群的DNS域名
CLUSTER_DNS_DOMAIN: "cluster.local."

#设置Master的VIP地址(必须修改)
MASTER_VIP: "172.16.18.212"

#设置网卡名称(必须修改)
VIP_IF: "ens160"

```

## 5.执行SaltStack状态

5.1 测试Salt SSH联通性

```bash
[root@k8s-m1 ~]# salt-ssh '*' test.ping
```
执行高级状态，会根据定义的角色再对应的机器部署对应的服务

5.2 部署Etcd，由于Etcd是基础组建，需要先部署，目标为部署etcd的节点。
```bash
[root@k8s-m1 ~]# salt-ssh -L 'k8s-m1,k8s-m2,k8s-m3' state.sls k8s.etcd
```
注：如果执行失败，新手建议推到重来，请检查各个节点的主机名解析是否正确（监听的IP地址依赖主机名解析）。

5.3 部署K8S集群
```bash
[root@k8s-m1 ~]# salt-ssh '*' state.highstate
```
由于包比较大，这里执行时间较长，5分钟+，喝杯咖啡休息一下，如果执行有失败可以再次执行即可！

## 6.测试Kubernetes安装
```
[root@k8s-m1 ~]# source /etc/profile
[root@k8s-m1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
[root@k8s-m1 ~]# kubectl get node
k8s-m1   Ready    master   4d15h   v1.12.5
k8s-m2   Ready    master   4d15h   v1.12.5
k8s-m3   Ready    master   4d15h   v1.12.5
k8s-n1   Ready    node     4d15h   v1.12.5
```
## 7.测试Kubernetes集群和Flannel网络

```
[root@k8s-m1 ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000
deployment "net-test" created
需要等待拉取镜像，可能稍有的慢，请等待。
[root@k8s-m1 ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-n9lvk   1/1       Running   0          14s       10.244.91.2   k8s-m1
net-test-5767cb94df-zclc5   1/1       Running   0          14s       10.244.92.4   k8s-n1

测试联通性，如果都能ping通，说明Kubernetes集群部署完毕，有问题请QQ群交流。
[root@k8s-m1 ~]# ping -c 1 10.244.92.4
PING 10.244.92.4 (10.244.92.4) 56(84) bytes of data.
64 bytes from 10.2.12.2: icmp_seq=1 ttl=61 time=8.72 ms

--- 10.244.92.4 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 8.729/8.729/8.729/0.000 ms

确认服务能够执行 logs exec 等指令;kubectl logs -f net-test-5767cb94df-n9lvk,此时会出现如下报错:
[root@k8s-m1 ~]# kubectl logs net-test-5767cb94df-n9lvk
error: You must be logged in to the server (the server has asked for the client to provide credentials ( pods/log net-test-5767cb94df-n9lvk))


由于上述权限问题，我们必需创建一个 apiserver-to-kubelet-rbac.yml 来定义权限，以供我们执行 logs、exec 等指令;
[root@k8s-m1 ~]# kubectl apply -f /srv/addons/apiserver-to-kubelet-rbac.yml
然后执行kubctl logs验证是否成功.
```
## 8.如何新增Kubernetes节点

- 1.设置SSH无密码登录
- 2.在/etc/salt/roster里面，增加对应的机器。
- 3.执行SaltStack状态salt-ssh '*' state.highstate。
```
[root@k8s-m1 ~]# vim /etc/salt/roster 
k8s-n2:
  host: 172.16.18.209
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
[root@linux-node1 ~]# salt-ssh 'k8s-n2' state.highstate
```

## 9.下一步要做什么？

你可以安装Kubernetes必备的插件
<table border="0">
    <tr>
        <td><strong>必备插件</strong></td>
        <td><a href="docs/coredns.md">1.CoreDNS部署</a></td>
        <td><a href="docs/dashboard.md">2.Dashboard部署</a></td>
        <td><a href="docs/heapster.md">3.Heapster部署</a></td>
        <td><a href="docs/ingress.md">4.Ingress部署</a></td>
        <td><a href="https://github.com/unixhot/devops-x">5.CI/CD</a></td>
    </tr>
</table>
### 为Master节点打上污点，让POD尽可能的不要调度到Master节点上。

关于污点的说明大家可自行百度。

```bash
kubectl describe node k8s-m1
kubectl taint node k8s-m1 node-role.kubernetes.io/master=k8s-m1:PreferNoSchedule
kubectl taint node k8s-m2 node-role.kubernetes.io/master=k8s-m2:PreferNoSchedule
kubectl taint node k8s-m3 node-role.kubernetes.io/master=k8s-m3:PreferNoSchedule
```
## 10. 已知的BUG

该BUG不影响svc内部之间的调用，但是会影响在节点上去访问对应的svc出现无法访问的情况。如果svc的后端pod在当前对应的节点上是可以进行访问的。

BUG重现：

```bash
[root@k8s-m1 k8s]# kubectl get svc
NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                         AGE
admin-auth-server-service       ClusterIP   10.245.222.77    <none>        8003/TCP                        32d
admin-gateway-server            NodePort    10.245.157.121   <none>        8002:30082/TCP,8502:30086/TCP   32d
erp-mechanisms-service-server   ClusterIP   10.245.212.18    <none>        7102/TCP                        32d
grammarback-server              NodePort    10.245.155.92    <none>        7104:30191/TCP                  32d
kubernetes                      ClusterIP   10.245.0.1       <none>        443/TCP                         32d
monitor-service-server          NodePort    10.245.88.137    <none>        8040:30195/TCP                  32d
nginx-service                   ClusterIP   10.245.227.62    <none>        80/TCP                          25d
pay-center-service-server       ClusterIP   10.245.49.60     <none>        7110/TCP                        32d
sleuth-zipkin-service-server    NodePort    10.245.254.192   <none>        9411:30196/TCP,9412:30197/TCP   32d
student-gateway-server          NodePort    10.245.210.19    <none>        8001:30081/TCP,8501:30085/TCP   32d
```
这个时候我再k8s-m1节点去访问nginx-service是无法访问的。


如果我再改svc对应的pod所在的节点，进行访问。这个时候是可以正常返回的。

```bash

#这里我们可以看到该nginx的pod所在的节点为k8s-n3
[root@k8s-m1 ~]# kubectl get pod -o wide
NAME                                                  READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE
admin-auth-server-deployment-75854d9688-w8l9r         1/1     Running   4          32d   10.244.91.47   k8s-n2   <none>
admin-gateway-deployment-794d74559f-wqzdq             1/1     Running   4          32d   10.244.91.45   k8s-n2   <none>
common-service-deployment-655979f885-zsk8t            1/1     Running   2          25d   10.244.91.41   k8s-n2   <none>
data-collection-service-deployment-54f5c865fc-pz5bh   1/1     Running   1          27d   10.244.36.28   k8s-n3   <none>
erp-mechanisms-service-deployment-7d75b6b88b-ztbkf    1/1     Running   2          32d   10.244.92.27   k8s-n4   <none>
gmr-server-deployment-56d789f9d6-sn46l                1/1     Running   0          22d   10.244.41.30   k8s-n1   <none>
grammarback-service-deployment-55f7fd8df9-ft6c7       1/1     Running   2          32d   10.244.92.22   k8s-n4   <none>
manage-service-deployment-5d65d44b75-rg88x            1/1     Running   1          27d   10.244.36.27   k8s-n3   <none>
medals-service-deployment-6fc7945c4f-4gl5v            1/1     Running   4          32d   10.244.91.46   k8s-n2   <none>
monitor-service-deployment-86674d75dd-f5g77           1/1     Running   2          32d   10.244.41.22   k8s-n1   <none>
nginx                                                 1/1     Running   1          26d   10.244.36.24   k8s-n3   <none>
pay-center-service-deployment-5f59fdc597-fqdgk        1/1     Running   8          32d   10.244.91.42   k8s-n2   <none>
sleuth-zipkin-service-deployment-dd5fc5665-kgrkm      1/1     Running   1          32d   10.244.36.29   k8s-n3   <none>
statistics-service-deployment-96f8df846-sd8zh         1/1     Running   2          32d   10.244.92.25   k8s-n4   <none>
student-gateway-deployment-7b7768d78f-cj259           1/1     Running   2          28d   10.244.41.25   k8s-n1   <none>
study-service-deployment-6c89bb9cdf-kcf9h             1/1     Running   0          20d   10.244.91.51   k8s-n2   <none>
task-service-deployment-7d8fc4d9c5-kncjw              1/1     Running   0          20d   10.244.36.31   k8s-n3   <none>
teach-research-service-deployment-65c86cdf74-wqx8h    1/1     Running   0          30m   10.244.41.37   k8s-n1   <none>
teacher-service-deployment-7bc8949f7d-ws9xz           1/1     Running   0          21d   10.244.91.50   k8s-n2   <none>
user-center-service-deployment-5d85769ddc-mjmfc       1/1     Running   2          32d   10.244.41.23   k8s-n1   <none>
usercenter-service-deployment-74d9675d5c-hnqjz        1/1     Running   0          21d   10.244.92.29   k8s-n4   <none>
word-job-service-deployment-66c775dc5b-6svr5          1/1     Running   0          19d   10.244.92.35   k8s-n4   <none>
word-service-deployment-5d968cd859-k9zmg              1/1     Running   0          19d   10.244.41.35   k8s-n1   <none>
#我们ssh到k8s-n3节点上。

#这里可以看到HTML页面的返回。
[root@k8s-n3 ~]# curl http://10.245.227.62
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <title>Test Page for the Nginx HTTP Server on Fedora</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <style type="text/css">
          ................
```

以下链接是我提交的issue，不过到现在还么有解决这个bug，唯一的解决办法是把kube-proxy的模式由ipvs改为iptables。这里也希望大家能帮忙解决一下。

```
https://github.com/opsnull/follow-me-install-kubernetes-cluster/issues/386
```


# 手动部署
- [系统内核升级](docs/update-kernel.md)
- [CA证书制作](docs/ca.md)
- [ETCD集群部署](docs/etcd-install.md)
- [Master节点部署](docs/master.md)
- [Node节点部署](docs/node.md)
- [Flannel网络部署](docs/flannel.md)
- [创建第一个K8S应用](docs/app.md)
- [CoreDNS和Dashboard部署](docs/dashboard.md)

