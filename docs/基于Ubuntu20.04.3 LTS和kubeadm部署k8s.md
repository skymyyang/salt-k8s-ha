## 基于Ubuntu 20.04.3 LTS 和 Kubeadm 部署k8s

### 说明

1. 建议使用root用户进行操作，虚拟机配置最低为2核4G
2. 系统是Ubuntu全新最小化安装，且安装时均已更改系统包安装源为阿里云的源
3. 所有机器最好为静态IP，如果是阿里云的ECS且IP固定亦可。
4. 我这里想要使用cilium进行网络插件测试，cilium插件要求，k8s必须配置CNI,且Linux kernel >=4.9.17,Ubuntu的内核是5.4.0-99是支持的

### 初始化配置

1. 关闭防火墙

   ```bash
   systemctl disable ufw 
   ufw disable
   ```

2. 修改时区

   ```bash
   ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
   ```

3. 检查`/etc/resolv.conf`

   coreDNS会proxy非集群的search（也就是pod访问外网，这个就是集群外的解析）到宿主机的/etc/resolv.conf里的nameserver，这个文件内容会和宿主机一样，Ubuntu系统会把DNS解析到`127.0.0.x`本地的一个DNS server,代理本地所有的DNS请求到公网，这样会导致POD无法解析到外网域名。

   这里我们需要禁用Ubuntu 20.04LTS 的reslove.conf中的127.0.0.53的代理。

   **PS: 我们在修改/etc/reslov.conf 中DNS的 nameserver 114.114.114.114，每次重启之后，就会重置为：127.0.0.53**

   **Override Ubuntu 20.04 DNS using systemd-resolved**

   打开`/etc/systemd/resolved.conf`,修改为：

   ```ini
   [Resolve]
   DNS=114.114.114.114
   #FallbackDNS=
   #Domains=
   LLMNR=no
   #MulticastDNS=no
   #DNSSEC=no
   #Cache=yes
   #DNSStubListener=yes
   ```

   LLMNR=设置的是禁止运行LLMNR(Link-Local Multicast Name Resolution)，否则systemd-resolve会监听5535端口。

   ```bash
    rm /etc/reslove.conf
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl restart systemd-resolved
   ```

   参考链接：https://unix.stackexchange.com/questions/588658/override-ubuntu-20-04-dns-using-systemd-resolved

   

   

4. 关闭swap交换分区

   k8s建议关闭Swap

   ```bash
   swapoff -a && sysctl -w vm.swappiness=0
   sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab
   ```

5. 安装依赖工具

   ```bash
   apt update && apt install -y wget \
     git \
     psmisc \
     nfs-kernel-server \
     nfs-common \
     jq \
     socat \
     bash-completion \
     ipset \
     ipvsadm \
     conntrack \
     libseccomp2 \
     net-tools \
     cron \
     sysstat \
     unzip \
     dnsutils \
     tcpdump \
     telnet \
     lsof \
     htop \
     curl \
     apt-transport-https \
     ca-certificates
   ```

   

6. 配置ipvs开机需要加载的模块，使用`systemd-modules-load`来加载

   ```bash
   :> /etc/modules-load.d/ipvs.conf
   module=(
   ip_vs
   ip_vs_rr
   ip_vs_wrr
   ip_vs_sh
   nf_conntrack
   br_netfilter
     )
   
   for kernel_module in ${module[@]};do
       /sbin/modinfo -F filename $kernel_module |& grep -qv ERROR && echo $kernel_module >> /etc/modules-load.d/ipvs.conf || :
   done
   ```

   使用`systemctl cat systemd-modules-load`看下是否有`Install`段，没有则执行：

   ```bash
   cat>>/usr/lib/systemd/system/systemd-modules-load.service<<EOF
   [Install]
   WantedBy=multi-user.target
   EOF
   ```

   启动该模块管理服务

   ```bash
   systemctl daemon-reload
   systemctl enable --now systemd-modules-load.service
   ```

   确认内核模块加载

   ```bash
   lsmod | grep ip_v
   #PS:这里我没有看到任何信息，需要系统重启，这里我们等后续准备工作完成后，统一重启
   ```

7. 内核参数优化

   设定`/etc/sysctl.d/k8s.conf`；关闭`IPV6`.

   ```bash
   cat <<EOF > /etc/sysctl.d/k8s.conf
   net.ipv6.conf.all.disable_ipv6 = 1
   net.ipv6.conf.default.disable_ipv6 = 1
   net.ipv6.conf.lo.disable_ipv6 = 1
   net.ipv4.neigh.default.gc_stale_time = 120
   net.ipv4.conf.all.rp_filter = 0
   net.ipv4.conf.default.rp_filter = 0
   net.ipv4.conf.default.arp_announce = 2
   net.ipv4.conf.lo.arp_announce = 2
   net.ipv4.conf.all.arp_announce = 2
   net.ipv4.ip_forward = 1
   net.ipv4.tcp_max_tw_buckets = 5000
   net.ipv4.tcp_syncookies = 1
   net.ipv4.tcp_max_syn_backlog = 1024
   net.ipv4.tcp_synack_retries = 2
   # 要求iptables不对bridge的数据进行处理
   net.bridge.bridge-nf-call-ip6tables = 1
   net.bridge.bridge-nf-call-iptables = 1
   net.bridge.bridge-nf-call-arptables = 1
   net.netfilter.nf_conntrack_max = 2310720
   fs.inotify.max_user_watches=89100
   fs.may_detach_mounts = 1
   fs.file-max = 52706963
   fs.nr_open = 52706963
   vm.overcommit_memory=1
   vm.panic_on_oom=0
   vm.swappiness = 0
   EOF
   
   ```

   如果kube-proxy使用ipvs的话，为了防止timeout需要设置下tcp参数。

   ```bash
   cat <<EOF >> /etc/sysctl.d/k8s.conf
   # https://github.com/moby/moby/issues/31208 
   # ipvsadm -l --timout
   # 修复ipvs模式下长连接timeout问题 小于900即可
   net.ipv4.tcp_keepalive_time = 600
   net.ipv4.tcp_keepalive_intvl = 30
   net.ipv4.tcp_keepalive_probes = 10
   EOF
   sysctl --system
   ```

   这里修改内核参数，部分会在重启之后失效，比如禁用IPV6.重启之后无法生效。

   需要配置相关服务的重新启动。

   ```bash
   vim /etc/rc.local
   #添加如下内容
   #!/bin/bash
   # /etc/rc.local
   
   /etc/sysctl.d
   /etc/init.d/procps restart
   
   exit 0
   
   #添加执行权限
   chmod 755 /etc/rc.local
   ```

   

   优化SSH连接，禁用DNS

   ```
   sed -ri 's/^#(UseDNS )yes/\1no/' /etc/ssh/sshd_config
   ```

   优化文件最大打开数，在子配置文件中定义

   ```bash
   cat>/etc/security/limits.d/kubernetes.conf<<EOF
   *       soft    nproc   131072
   *       hard    nproc   131072
   *       soft    nofile  131072
   *       hard    nofile  131072
   root    soft    nproc   131072
   root    hard    nproc   131072
   root    soft    nofile  131072
   root    hard    nofile  131072
   EOF
   ```

8. 同步Internet时间

   ```bash
   apt install -y chrony
   ```

   由于默认的配置文件亦可进行时间同步，这里不再进行修改。

9. 重启系统

   ```bash
   reboot
   ```

### 安装Docker

1. 安装依赖

   ```bash
   apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
   ```

2. 添加docker的GPG公钥,这里添加的华为云的源

   ```bash
   curl -fsSL https://repo.huaweicloud.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
   ```

3. 添加仓库，添加华为云的源

   ```bash
   add-apt-repository "deb [arch=amd64] https://repo.huaweicloud.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
   apt update 
   ```

4. 安装docker指定版本(查看k8s官方文档，确认版本，20.10版本暂时好像是不兼容的)

   ```bash
   apt install docker-ce=5:19.03.15~3-0~ubuntu-focal -y
   ```

5. 修改docker配置文件

   ```bash
   mkdir -p /etc/docker/
   cat>/etc/docker/daemon.json<<EOF
   {
     "exec-opts": ["native.cgroupdriver=systemd"],
     "bip": "169.254.123.1/24",
     "registry-mirrors": [
         "https://fz5yth0r.mirror.aliyuncs.com",
         "https://dockerhub.mirrors.nwafu.edu.cn/",
         "https://mirror.ccs.tencentyun.com",
         "https://docker.mirrors.ustc.edu.cn/",
         "https://reg-mirror.qiniu.com",
         "http://hub-mirror.c.163.com/",
         "https://registry.docker-cn.com"
     ],
     "storage-driver": "overlay2",
     "storage-opts": [
       "overlay2.override_kernel_check=true"
     ],
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "100m",
       "max-file": "3"
     }
   }
   EOF
   ```

6. 重启docker

   ````bash
   systemctl restart docker
   systemctl enable docker
   ````

7. 设置docker命令补全

   取消文件/etc/bash.bashrc内下面行的注释

   ```bash
   # enable bash completion in interactive shells
   #if ! shopt -oq posix; then
   #  if [ -f /usr/share/bash-completion/bash_completion ]; then
   #    . /usr/share/bash-completion/bash_completion
   #  elif [ -f /etc/bash_completion ]; then
   #    . /etc/bash_completion
   #  fi
   #fi
   ```

   复制补全脚本

   ```bash
   cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
   ```

   配置环境变量

   ```bash
   source /usr/share/bash-completion/bash_completion
   echo "source <(kubectl completion bash)" >> ~/.bashrc
   ```

   



## kubeadm部署

### 安装kubeadm相关

默认源在国外会无法安装，我们使用国内的镜像源，所有机器都需要操作。(这里使用的是阿里云的源，华为云源签名验证不通过)

```bash
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat>/etc/apt/sources.list.d/kubernetes.list<<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt update
```

安装相关软件

```bash
apt install kubeadm=1.23.3-00 kubelet=1.23.3-00 kubectl=1.23.3-00
```

准备初始化文件

```bash
#首先生成初始化文件
kubeadm config print init-defaults > initconfig.yaml
修改后的内容如下：

```

这里由于我们的网络组件使用cilium。且依然使用cilium代理svc层，所以我们在初始化时，需要拒绝使用kube-proxy。

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
imageRepository: registry.aliyuncs.com/k8sxio
kubernetesVersion: v1.23.3 # 如果镜像列出的版本不对就这里写正确版本号
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
networking: #https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
apiServer: # https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#APIServer
  timeoutForControlPlane: 4m0s
  certSANs:
  - 10.96.0.1 # service cidr的第一个ip
  - 127.0.0.1 # 多个master的时候负载均衡出问题了能够快速使用localhost调试
  - localhost
  - 192.168.10.81
  - master
  - kubernetes
  - kubernetes.default
  - kubernetes.default.svc
  - kubernetes.default.svc.cluster.local
  extraVolumes:
  - hostPath: /etc/localtime
    mountPath: /etc/localtime
    name: localtime
    readOnly: true
controllerManager: # https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#ControlPlaneComponent
  extraArgs:
    bind-address: "0.0.0.0"
    experimental-cluster-signing-duration: 876000h
  extraVolumes:
  - hostPath: /etc/localtime
    mountPath: /etc/localtime
    name: localtime
    readOnly: true
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
  extraVolumes:
  - hostPath: /etc/localtime
    mountPath: /etc/localtime
    name: localtime
    readOnly: true
dns: # https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#DNS
  imageRepository: docker.io/coredns # azk8s.cn已失效,此处使用上面的ns下镜像，使用dockerhub上coredns官方镜像，下面的images list如果显示不对，这里改成docker.io/coredns再试试
  imageTag: 1.8.7
etcd: # https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#Etcd
  local:
    #imageRepository: quay.io/coreos #取消注释使用quay.io，这里使用registry.aliyuncs.com/k8sxio的
    imageTag: v3.4.15
    dataDir: /var/lib/etcd
    extraArgs: # 官方暂时没有extraVolumes
      auto-compaction-retention: "1h"
      max-request-bytes: "33554432"
      quota-backend-bytes: "8589934592"
      enable-v2: "false" # disable etcd v2 api
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration # https://godoc.org/k8s.io/kubelet/config/v1beta1#KubeletConfiguration
cgroupDriver: systemd
failSwapOn: true # 如果开启swap则设置为false
```

验证配置文件是否报错

```bash
kubeadm init --config initconfig.yaml --dry-run
```

拉取镜像

```bash
kubeadm config images list --config initconfig.yaml
kubeadm config images pull --config initconfig.yaml
```

进行初始化，且跳过kube-proxy

```bash
kubeadm init --config initconfig.yml --skip-phases=addon/kube-proxy
```

初始化完成之后，会出现配置kubectl管理员以及将子节点加入集群中的提示。

配置kubectl

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

将子节点加入到集群中

```bash
kubeadm join 192.168.10.81:6443 --token 9b2qv2.vgge4e62maud7hxx         --discovery-token-ca-cert-hash sha256:ed13dd55246982df17f809fd3355745e61b788fb9c745ac437aa2b3624511df0
```

此时没有配置cilium网络组建，所有节点均处于`NotReady`状态。如下：

```bash
root@unode1:~# kubectl get node -o wide
NAME                    STATUS     ROLES                  AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
unode1   NotReady   control-plane,master   7m45s   v1.23.3   192.168.10.81   <none>        Ubuntu 20.04.3 LTS   5.4.0-99-generic   docker://19.3.15
unode2   NotReady   <none>                 6m24s   v1.23.3   192.168.10.82   <none>        Ubuntu 20.04.3 LTS   5.4.0-99-generic   docker://19.3.15
unode3   NotReady   <none>                 6m12s   v1.23.3   192.168.10.83   <none>        Ubuntu 20.04.3 LTS   5.4.0-99-generic   docker://19.3.15

```

### 配置cilium插件

到GitHub上下载对应版本的`cilium-cli`

地址：# https://github.com/cilium/cilium-cli/releases

参考官方文档：# https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

```bash
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}
```

**Requirements:**

- Kubernetes must be configured to use CNI (see [Network Plugin Requirements](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/#network-plugin-requirements))
- Linux kernel >= 4.9.17

如上是cilium的部署要求。

#### 安装helm

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

#### cilium的IPAM

官网地址：https://docs.cilium.io/en/stable/concepts/networking/ipam/

IP地址管理（IPAM）负责分配和管理cilium管理的网络终点（容器和其他）使用的IP地址。支持多种IPAM模式：

- Cluster Scope（Default） 集群范围, 默认的cilium管理地址方式，默认地址为：10.0.0.0/8 子网掩码划分为：24
- Kubernetes Host Scope   k8s主机范围，在安装cilium时需要指定ipam: kubernetes参数
- Azure IPAM  使用Azure 的IPAM管理进行IP地址分配，   
- AWS ENI   使用AWS ENI进行IPAM 管理
- Google Kubernetes Engine   使用谷歌云k8s引擎进行IPAM
- CRD-Backed   
- Technical Deep Dive 

#### cilium安装

1. 使用cilium install 

   这里如果使用Cluster Scope集群范围，建议使用此种方式进行安装

   建议安装前进行--help，详细阅读各个参数的意义，然后进行自定义。

   ```bash
   cilium install
   ```

2. 使用helm进行安装

   这里是个人比较推荐的方式；官方文档：https://github.com/cilium/cilium/tree/master/install/kubernetes/cilium

   这里我们的IPAM 选择使用`Kubernetes Host Scope`

   由于我们在配置k8s集群的时候指定了PodCIDR，我们需要与其保持一致，且controller-manager需要配置：

   `--allocate-node-cidrs=true`和`--cluster-cidr=10.244.0.0/16`这两个参数。

   With helm the previous options can be defined as:

   > - `ipam: kubernetes`: `--set ipam.mode=kubernetes`.
   > - `k8s-require-ipv4-pod-cidr: true`: `--set k8s.requireIPv4PodCIDR=true`, which only works with `--set ipam.mode=kubernetes`
   > - `k8s-require-ipv6-pod-cidr: true`: `--set k8s.requireIPv6PodCIDR=true`, which only works with `--set ipam.mode=kubernetes`
   > - 

​               如上所示，是官网给出的我们需要进行helm参数的配置。

3.  配置helm 参数

   ```bash
   #将对应版本的cilium仓库下载下来
   helm repo add cilium https://helm.cilium.io/
   mkdir /opt/helmrepo
   cd /opt/helmrepo/
   helm repo list
   helm search repo -l cilium/cilium
   helm fetch cilium/cilium --version=1.11.1
   #这里我们将对应版本的 cilium charts下载下来，然后修改values.yaml进行配置
   ```

   修改的配置如下：

   ```
   k8sServiceHost: 192.168.10.81
   k8sServicePort: 6443
   extraHostPathMounts:
     - name: localtime
       mountPath: /etc/localtime
       hostPath: /etc/localtime
       readOnly: true
   resources:
     limits:
       cpu: 2000m
       memory: 2Gi
     requests:
       cpu: 100m
       memory: 512Mi
   ipam:
     # -- Configure IP Address Management mode.
     # ref: https://docs.cilium.io/en/stable/concepts/networking/ipam/
     mode: "kubernetes"
     operator:
       # -- Deprecated in favor of ipam.operator.clusterPoolIPv4PodCIDRList.
       # IPv4 CIDR range to delegate to individual nodes for IPAM.
       clusterPoolIPv4PodCIDR: "10.244.0.0/16"
       # -- IPv4 CIDR list range to delegate to individual nodes for IPAM.
       clusterPoolIPv4PodCIDRList: []
       # -- IPv4 CIDR mask size to delegate to individual nodes for IPAM.
       clusterPoolIPv4MaskSize: 24
       
   ipv4:
     # -- Enable IPv4 support.
     enabled: true
   k8s:
     # -- requireIPv4PodCIDR enables waiting for Kubernetes to provide the PodCIDR
     # range via the Kubernetes node resource
     requireIPv4PodCIDR: true
     
   kubeProxyReplacement: "strict"
   tunnel: "vxlan"
   operator:
   # -- Additional cilium-operator hostPath mounts.
     extraHostPathMounts:
       - name: localtime
         mountPath: /etc/localtime
         hostPath: /etc/localtime
         readOnly: true
     # -- cilium-operator resource limits & requests
     # ref: https://kubernetes.io/docs/user-guide/compute-resources/
     resources:
       limits:
         cpu: 1000m
         memory: 1Gi
       requests:
         cpu: 100m
         memory: 128Mi
   ```

   然后进行安装：

               ```bash
   helm install cilium --namespace kube-system ./cilium
   #如果后续还有其他value值进行更新，可通过如下命令：
   helm upgrade cilium --namespace kube-system ./cilium
               ```

   最后进行验证：

   ```
   root@unode1:/opt/helmrepo# cilium status
       /¯¯\
    /¯¯\__/¯¯\    Cilium:         OK
    \__/¯¯\__/    Operator:       OK
    /¯¯\__/¯¯\    Hubble:         disabled
    \__/¯¯\__/    ClusterMesh:    disabled
       \__/
   
   DaemonSet         cilium             Desired: 3, Ready: 3/3, Available: 3/3
   Deployment        cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
   Containers:       cilium             Running: 3
                     cilium-operator    Running: 2
   Cluster Pods:     6/6 managed by Cilium
   Image versions    cilium             quay.io/cilium/cilium:v1.11.1@sha256:251ff274acf22fd2067b29a31e9fda94253d2961c061577203621583d7e85bd2: 3
                     cilium-operator    quay.io/cilium/operator-generic:v1.11.1@sha256:977240a4783c7be821e215ead515da3093a10f4a7baea9f803511a2c2b44a235: 2
   ```

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

   

