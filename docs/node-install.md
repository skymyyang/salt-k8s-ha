## 部署kubelet

- kublet 运行在每个 worker 节点上，接收 kube-apiserver 发送的请求，管理 Pod 容器，执行交互式命令，如 exec、run、logs 等。
- kublet 启动时自动向 kube-apiserver 注册节点信息，内置的 cadvisor 统计和监控节点的资源使用情况
- 为确保安全，本文档只开启接收 https 请求的安全端口，对请求进行认证和授权，拒绝未授权的访问(如 apiserver、heapster)。

### 1.分发二进制包

```Bash
cd /usr/local/src/kubernetes
cp server/bin/kubelet /opt/kubernetes/bin/
cp server/bin/kube-proxy /opt/kubernetes/bin
mkdir /var/lib/kubelet
```

### 2.创建 kubelet bootstrap kubeconfig 文件

```Bash
cd /opt/kubernetes/cfg
/opt/kubernetes/bin/kubectl config set-cluster kubernetes \
 --certificate-authority=/opt/kubernetes/ssl/ca.pem \
 --embed-certs=true \
 --server=https://27.0.0.1:8443 \
 --kubeconfig=kubelet-bootstrap.kubeconfig

/opt/kubernetes/bin/kubectl config set-credentials tls-bootstrap-token-user \
 --token="be8dad.da8a699a46edc482" \
 --kubeconfig=kubelet-bootstrap.kubeconfig

/opt/kubernetes/bin/kubectl config set-context tls-bootstrap-token-user@kubernetes \
 --cluster=kubernetes \
 --user=tls-bootstrap-token-user \
 --kubeconfig=kubelet-bootstrap.kubeconfig

/opt/kubernetes/bin/kubectl config use-context tls-bootstrap-token-user@kubernetes --kubeconfig=kubelet-bootstrap.kubeconfig
```
- 证书中写入 Token 而非证书，证书后续由 kube-controller-manager 创建。

### 3.分发 bootstrap kubeconfig 文件到所有 worker 节点

```Bash
cd /opt/kubernetes/cfg
scp kubelet-bootstrap.kubeconfig linux-node2:/opt/kubernetes/cfg/
scp kubelet-bootstrap.kubeconfig linux-node3:/opt/kubernetes/cfg/
scp kubelet-bootstrap.kubeconfig linux-node4:/opt/kubernetes/cfg/
```
### 4.创建和分发 kubelet 参数配置文件

- 从 v1.10 开始，kubelet 部分参数需在配置文件中配置，kubelet --help 会提示
- 创建 kubelet 参数配置模板文件

```Bash
#创建静态POD的路径
/opt/kubernetes/manifests
[root@linux-node1 ~]# cat /opt/kubernetes/cfg/kubelet-conf.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /opt/kubernetes/ssl/ca.pem
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
cgroupDriver: cgroupfs
cgroupsPerQOS: true
clusterDNS:
- 10.1.0.2
clusterDomain: cluster.local.
podCIDR: 10.2.0.0/16
containerLogMaxFiles: 5
containerLogMaxSize: 10Mi
contentType: application/vnd.kubernetes.protobuf
cpuCFSQuota: true
cpuManagerPolicy: none
cpuManagerReconcilePeriod: 10s
enableControllerAttachDetach: true
enableDebuggingHandlers: true
enforceNodeAllocatable:
- pods
eventBurst: 10
eventRecordQPS: 5
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionPressureTransitionPeriod: 5m0s
failSwapOn: true
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
kubeAPIBurst: 10
kubeAPIQPS: 5
makeIPTablesUtilChains: true
maxOpenFiles: 1000000
maxPods: 110
nodeStatusUpdateFrequency: 10s
oomScoreAdj: -999
podPidsLimit: -1
registryBurst: 10
registryPullQPS: 5
resolvConf: /etc/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 2m0s
serializeImagePulls: true
staticPodPath: /opt/kubernetes/manifests
streamingConnectionIdleTimeout: 4h0m0s
syncFrequency: 1m0s
volumeStatsAggPeriod: 1m0s
```
- address：API 监听地址，不能为 127.0.0.1，否则 kube-apiserver、heapster 等不能调用 kubelet 的 API
- readOnlyPort=0：关闭只读端口(默认 10255)，等效为未指定
- authentication.anonymous.enabled：设置为 false，不允许匿名�访问 10250 端口
- authentication.x509.clientCAFile：指定签名客户端证书的 CA 证书，开启 HTTP 证书认证
- authentication.webhook.enabled=true：开启 HTTPs bearer token 认证
- 对于未通过 x509 证书和 webhook 认证的请求(kube-apiserver 或其他客户端)，将被拒绝，提示 Unauthorized
- authroization.mode=Webhook：kubelet 使用 SubjectAccessReview API 查询 kube-apiserver 某 user、group 是否具有操作资源的权限(RBAC)
- featureGates.RotateKubeletClientCertificate、featureGates.RotateKubeletServerCertificate：自动 rotate 证书，证书的有效期取决于 kube-controller-manager 的 --experimental-cluster-signing-duration 参数
- 需要 root 账户运行

为各节点分发 kubelet 配置文件。

### 5.设置CNI支持

创建相关目录

```Bash
mkdir /etc/cni/net.d -p
mkdir /opt/kubernetes/bin/cni
```

将cni插件的二进制文件都统一放到`mkdir /opt/kubernetes/bin/cni`目录下。

```Bash
cp files/cni-plugins-amd64-v0.7.4/* /opt/kubernetes/bin/
```

创建CNI相关配置文件

```Bash
cat /etc/cni/net.d/10-flannel.conflist
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
```

### 6.创建和分发 kubelet systemd unit 文件

创建 kubelet systemd unit 文件

```Bash
[root@linux-node1 ~]# cat /usr/lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/opt/kubernetes/bin/kubelet \
  --bootstrap-kubeconfig=/opt/kubernetes/cfg/kubelet-bootstrap.kubeconfig \
  --kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \
  --network-plugin=cni \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/kubernetes/bin/cni \
  --config=/opt/kubernetes/cfg/kubelet-conf.yaml \
  --node-labels=node-role.kubernetes.io/master=linux-node1 \
  --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1 \
  --cert-dir=/opt/kubernetes/ssl \
  --hostname-override=linux-node1 \
  --allowed-unsafe-sysctls="net.*" \
  --fail-swap-on=false \
  --allow-privileged=true \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```
- 如果设置了 --hostname-override 选项，则 kube-proxy 也需要设置该选项，否则会出现找不到 Node 的情况
- --bootstrap-kubeconfig：指向 bootstrap kubeconfig 文件，kubelet 使用该文件中的用户名和 token 向 kube-apiserver 发送 TLS Bootstrapping 请求
- K8S approve kubelet 的 csr 请求后，在 --cert-dir 目录创建证书和私钥文件，然后写入 --kubeconfig 文件
- --pod-infra-container-image 不使用 redhat 的 pod-infrastructure:latest 镜像，它不能回收容器的僵尸


为各节点创建和分发 kubelet systemd unit 文件,需要根据各节点信息修改相关配置。

### 7.配置 bootstrap-在master上执行一次即可。

由于本次安装启用了TLS认证,因此每个节点的kubelet都必须使用kube-apiserver的CA的凭证后,才能与kube-apiserver进行沟通,而该过程需要手动针对每台节点单独签署凭证是一件繁琐的事情,且一旦节点增加会延伸出管理不易问题;而TLS bootstrapping目标就是解决该问题,通过让kubelet先使用一个预定低权限使用者连接到kube-apiserver,然后在对kube-apiserver申请凭证签署,当授权Token一致时,Node节点的kubelet凭证将由kube-apiserver动态签署提供

```Bash
[root@linux-node1 ~]# cat /opt/kubernetes/cfg/bootstrap-token-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-be8dad
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  token-id: be8dad
  token-secret: da8a699a46edc482
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:default-node-token

[root@linux-node1 ~]# /opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/bootstrap-token-secret.yaml
```

### 8.自动 approve CSR 请求-在master上执行一次即可。

```Bash
[root@linux-node1 ~]# cat /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubelet-bootstrap
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:node-bootstrapper
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:bootstrappers:default-node-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-autoapprove-bootstrap
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:bootstrappers:default-node-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-autoapprove-certificate-rotation
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:nodes

/opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml
```
### 9.启动Kubelet

```Bash
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable kubelet
[root@linux-node1 ~]# systemctl start kubelet
[root@linux-node1 ~]# systemctl status kubelet
```

## 部署 kube-proxy 组件

- kube-proxy 运行在所有 worker 节点上，，它监听 apiserver 中 service 和 Endpoint 的变化情况，创建路由规则来进行服务负载均衡
- 使用 ipvs 模式
- 各节点需要安装 ipvsadm 和 ipset 命令，加载 ip_vs 内核模块,详情参考系统初始化以及升级内核的模块。

### 1.创建 kube-proxy 证书

创建证书签名请求：

```Bash
cat /opt/kubernetes/ssl/kube-proxy-csr.json
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
- CN：指定该证书的 User 为 system:kube-proxy
- 预定义的 RoleBinding system:node-proxier 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限
- 该证书只会被 kube-proxy 当做 client 证书使用，所以 hosts 字段为空

生成证书和私钥:

```Bash
cd /opt/kubernetes/ssl
/opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
 -ca-key=/opt/kubernetes/ssl/ca-key.pem \
 -config=/opt/kubernetes/ssl/ca-config.json \
 -profile=kubernetes  kube-proxy-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-proxy

ls kube-proxy*
```

### 2.创建和分发 kubeconfig 文件

```Bash
cd /opt/kubernetes/cfg
/opt/kubernetes/bin/kubectl config set-cluster kubernetes \
 --certificate-authority=/opt/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=https://127.0.0.1:8443  \
--kubeconfig=kube-proxy.kubeconfig

/opt/kubernetes/bin/kubectl config set-credentials kube-proxy \
 --client-certificate=/opt/kubernetes/ssl/kube-proxy.pem \
 --client-key=/opt/kubernetes/ssl/kube-proxy-key.pem \
 --embed-certs=true \
 --kubeconfig=kube-proxy.kubeconfig

/opt/kubernetes/bin/kubectl config set-context default --cluster=kubernetes \
 --user=kube-proxy \
 --kubeconfig=kube-proxy.kubeconfig

/opt/kubernetes/bin/kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```
- --embed-certs=true：将 ca.pem 和 admin.pem 证书内容嵌入到生成的 kubectl-proxy.kubeconfig 文件中

分发 kubeconfig 文件,到其他节点。

### 3.创建 kube-proxy 配置文件

```Bash
[root@linux-node1 ~]#  cat /opt/kubernetes/cfg/kube-proxy.config.yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 192.168.150.141
clientConnection:
    acceptContentTypes: ""
    burst: 10
    contentType: application/vnd.kubernetes.protobuf
    kubeconfig: /opt/kubernetes/cfg/kube-proxy.kubeconfig
    qps: 5
clusterCIDR: 10.2.0.0/16
configSyncPeriod: 15m0s
conntrack:
    max: null
    maxPerCore: 32768
    min: 131072
    tcpCloseWaitTimeout: 1h0m0s
    tcpEstablishedTimeout: 24h0m0s
enableProfiling: false
healthzBindAddress: 192.168.150.141:10256
hostnameOverride: linux-node1
iptables:
    masqueradeAll: true
    masqueradeBit: 14
    minSyncPeriod: 0s
    syncPeriod: 30s
ipvs:
    excludeCIDRs: null
    minSyncPeriod: 0s
    scheduler: ""
    syncPeriod: 30s
kind: KubeProxyConfiguration
metricsBindAddress: 192.168.150.141:10249
mode: "ipvs"
nodePortAddresses: null
oomScoreAdj: -999
portRange: ""
resourceContainer: /kube-proxy
udpIdleTimeout: 250ms
```
- bindAddress: 监听地址
- clientConnection.kubeconfig: 连接 apiserver 的 kubeconfig 文件
- clusterCIDR: kube-proxy 根据 --cluster-cidr 判断集群内部和外部流量，指定 --cluster-cidr 或 --masquerade-all 选项后 kube-proxy 才会对访问 Service IP 的请求做 SNAT
- hostnameOverride: 参数值必须与 kubelet 的值一致，否则 kube-proxy 启动后会找不到该 Node，从而不会创建任何 ipvs 规则
- mode: 使用 ipvs 模式

为各节点创建和分发 kube-proxy 配置文件，并根据各节点信息进行修改。

### 4.创建和分发 kube-proxy systemd unit 文件

```Bash
[root@linux-node1 ~]# cat /usr/lib/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/opt/kubernetes/bin/kube-proxy \
  --config=/opt/kubernetes/cfg/kube-proxy.config.yaml \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log \
  --v=2

Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

### 5.启动 kube-proxy 服务

```Bash
systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy
journalctl -u kube-proxy
netstat -lnpt|grep kube-prox
```

### 6.查看 ipvs 路由规则

```Bash
/usr/sbin/ipvsadm -ln
```
