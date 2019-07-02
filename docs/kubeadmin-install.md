## kubeadm部署kubernetes HA集群

1. etcd集群使用二进制部署，使用HTTP协议。
2. 修改源码，重新编译kubeadm，调整证书时间为10年。
3. 基于saltstack部署ETCD以及系统优化。
4. 安装docker，参考阿里云的docker参数进行优化。

## 一.初始化系统环境

1. 升级内核，参考[此文档](update-kernel.md)。
2. 设置主机名，并添加对应解析。

```bash
[root@kubeadm-master-01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.200.101 kubeadm-master-01
192.168.200.102 kubeadm-master-02
192.168.200.103 kubeadm-master-03
192.168.200.104 kubeadm-node-01
192.168.200.105 kubeadm-node-02
192.168.200.106 kubeadm-node-03
192.168.200.107 kubeadm-node-04
192.168.200.108 kubeadm-node-05
```
3. 设置免密登录

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
4. 安装salt-ssh，以及docker-ce的阿里云yum源。

```bash
[root@kubeadm-master-01 ~]# yum install -y https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
[root@kubeadm-master-01 ~]# sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
[root@kubeadm-master-01 ~]# yum install -y salt-ssh git unzip p7zip psmisc socat wget
[root@kubeadm-master-01 ~]# yum install -y yum-utils device-mapper-persistent-data lvm2
[root@kubeadm-master-01 ~]# yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

5. 配置kubernetes阿里云的yum源。
```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

## 二. 安装部署etcd和kube-nginx

1. 安装docker,所有节点执行。
```bash
yum list docker-ce.x86_64 --showduplicates | sort -r
yum install docker-ce-18.09.2
```
2. 修改docker配置文件，所有节点执行。

```bash
cat <<EOF > /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",
    "oom-score-adjust": -1000,
    "registry-mirrors": ["https://fz5yth0r.mirror.aliyuncs.com"],
    "storage-driver": "overlay2",
    "storage-opts":["overlay2.override_kernel_check=true"]
}
EOF
```
3. 启动docker，所有节点执行。

```bash
systemctl enable docker
systemctl start docker
```
4. 安装kubectl kubelet kebeadm， 所有节点均需执行

```bash
yum install kubelet-1.14.3 kubeadm-1.14.3 kubectl-1.14.3
```
5. 安装ETCD

5.1 准备二进制文件
```bash
git clone https://github.com/skymyyang/salt-k8s-ha.git
cd salt-k8s-ha/
mv * /srv/
/bin/cp /srv/roster /etc/salt/roster
/bin/cp /srv/master /etc/salt/master
#下载etcd的二进制文件
https://github.com/etcd-io/etcd/releases
cd /srv/salt/k8s/
mkdir /srv/salt/k8s/files/etcd-v3.3.13-linux-amd64 -p
#将下载后的etcd二进制文件，存放到这个目录下
```
5.2 Salt SSH管理的机器以及角色分配

- k8s-role: 用来设置K8S的角色
- etcd-role: 用来设置etcd的角色，如果只需要部署一个etcd，只需要在一台机器上设置即可
- etcd-name: 如果对一台机器设置了etcd-role就必须设置etcd-name


```bash
vim /etc/salt/roster

kubeadm-master-01:
  host: 192.168.200.101
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      etcd-role: node
      etcd-name: etcd-01

kubeadm-master-02:
  host: 192.168.200.102
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      etcd-role: node
      etcd-name: etcd-02

kubeadm-master-03:
  host: 192.168.200.103
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      etcd-role: node
      etcd-name: etcd-03

kubeadm-node-01:
  host: 192.168.200.104
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
```

5.3 修改对应的配置参数，本项目使用Salt Pillar保存配置,本配置只用了安装ETCD，其他参数可以不用修改。

```
vim /srv/pillar/k8s.sls
#设置Master的IP地址(必须修改)
MASTER_IP_M1: "192.168.200.101"
MASTER_IP_M2: "192.168.200.102"
MASTER_IP_M3: "192.168.200.103"
#设置Master的HOSTNAME完整的FQDN名称(必须修改)
MASTER_H1: "kubeadm-master-01"
MASTER_H2: "kubeadm-master-02"
MASTER_H3: "kubeadm-master-03"

#KUBE-APISERVER的反向代理地址端口
KUBE_APISERVER: "https://127.0.0.1:8443"

#设置ETCD集群访问地址（必须修改）
ETCD_ENDPOINTS: "http://192.168.200.101:2379,http://192.168.200.102:2379,http://192.168.200.103:2379"

FLANNEL_ETCD_PREFIX: "/kubernetes/network"

#设置ETCD集群初始化列表（必须修改）
ETCD_CLUSTER: "etcd-01=http://192.168.200.101:2380,etcd-02=http://192.168.200.102:2380,etcd-03=http://192.168.200.103:2380"

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

#设置网卡名称，一定要改
VIP_IF: "eth0"
```
5.4 执行SaltStack状态

- 测试Salt SSH联通性
```
salt-ssh '*' test.ping
```
- 安装etcd
```
salt-ssh -L 'linux-node1,linux-node2,linux-node3' state.sls k8s.etcd
```
6. 安装kube-nginx
```
salt-ssh -L 'kubeadm-master-01,kubeadm-master-02,kubeadm-master-03' state.sls k8s.modules.nginx
```
## 三. 安装kubernetes集群
1. 配置kubeadm-config.yaml

```
vim kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.14.3
#useHyperKubeImage: true
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
apiServer:
  certSANs:
    - "127.0.0.1"
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16

controlPlaneEndpoint: 127.0.0.1:8443

etcd:
  external:
    endpoints:
      - http://192.168.200.101:2379
      - http://192.168.200.102:2379
      - http://192.168.200.103:2379
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
ipvs:
  scheduler: rr
  syncPeriod: 10s
```
2.  拉取镜像

```
kubeadm config images pull --config kubeadm-config.yaml
```
3.  初始化集群

```
kubeadm init --config kubeadm-config.yaml
```
4.  初始化完成之后，输出如下。

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 127.0.0.1:8443 --token xa6317.1tyqmsnbt7wwhqfe \
    --discovery-token-ca-cert-hash sha256:52c45df8f04b675869ad60a42c76e997d6a0da806107aa6f2e4f2963efbc4485 \
    --experimental-control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 127.0.0.1:8443 --token xa6317.1tyqmsnbt7wwhqfe \
    --discovery-token-ca-cert-hash sha256:52c45df8f04b675869ad60a42c76e997d6a0da806107aa6f2e4f2963efbc4485
```
5. 拷贝证书到其他master节点
```bash
openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -text
USER=root
CONTROL_PLANE_IPS="192.168.200.102 192.168.200.103"
for host in ${CONTROL_PLANE_IPS}; do
    scp /etc/kubernetes/pki/ca.crt "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/ca.key "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/sa.key "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/sa.pub "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/admin.conf "${USER}"@$host:/etc/kubernetes/
done
# scp /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:/etc/kubernetes/pki/etcd/ca.crt
# scp /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:/etc/kubernetes/pki/etcd/ca.key
```
6. 在其他的master节点上执行,此命令就是最上面的那个输出结果中获取

```Bash
kubeadm join 127.0.0.1:8443 --token xa6317.1tyqmsnbt7wwhqfe     --discovery-token-ca-cert-hash sha256:52c45df8f04b675869ad60a42c76e997d6a0da806107aa6f2e4f2963efbc4485     --experimental-control-plane
```
7. 部署flannel

```Bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yaml
kubectl apply -f flannel.yaml
```
8. 查看集群

```Bash
[root@kubeadm-master-01 addons]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
```
## 四.添加node节点

- 1.设置SSH无密码登录，并且在 `/etc/hosts` 中继续增加对应的解析。确保所有节点都能解析。
- 2.在 `/etc/salt/roster` 里面，增加对应的机器。
- 3.执行SaltStack状态

```
salt-ssh -L 'kubeadm-node-01' state.sls k8s.modules.base-dir
salt-ssh -L 'kubeadm-node-01' state.sls k8s.modules.nginx
systemctl status kube-nginx
kubeadm join 127.0.0.1:8443 --token xa6317.1tyqmsnbt7wwhqfe \
    --discovery-token-ca-cert-hash sha256:52c45df8f04b675869ad60a42c76e997d6a0da806107aa6f2e4f2963efbc4485
```
