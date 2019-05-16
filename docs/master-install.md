## 部署Kubernetes API服务部署

### 0.准备软件包
```
[root@linux-node1 ~]# cd /usr/local/src/kubernetes
[root@linux-node1 kubernetes]# cp server/bin/kube-apiserver /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-controller-manager /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-scheduler /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kubectl /opt/kubernetes/bin/
```

### 1.创建生成CSR的 JSON 配置文件
```
[root@linux-node1 src]# vim kubernetes-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "192.168.150.141",
    "192.168.150.142",
    "192.168.150.143",
    "10.1.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
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
- hosts 字段指定授权使用该证书的 IP 或域名列表，这里列出了 VIP 、apiserver 节点 IP、kubernetes 服务 IP 和域名
- 域名最后字符不能是 .(如不能为 kubernetes.default.svc.cluster.local.)，否则解析时失败，提示： x509: cannot parse dnsName "kubernetes.default.svc.cluster.local."；
- 如果使用非 cluster.local 域名，如 mofangge.com，则需要修改域名列表中的最后两个域名为：kubernetes.default.svc.mofangge、kubernetes.default.svc.mofangge.com
- kubernetes 服务 IP 是 apiserver 自动创建的，一般是 --service-cluster-ip-range 参数指定的网段的第一个IP，后续可以通过如下命令获取：

```Bash
$ kubectl get svc kubernetes
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.1.0.1   <none>        443/TCP   1d
```

### 2.生成 kubernetes 证书和私钥,并拷贝至其他所有节点

```Bash
 [root@linux-node1 src]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
[root@linux-node1 src]# cp kubernetes*.pem /opt/kubernetes/ssl/
[root@linux-node1 ~]# scp kubernetes*.pem linux-node2:/opt/kubernetes/ssl/
[root@linux-node1 ~]# scp kubernetes*.pem linux-node3:/opt/kubernetes/ssl/
[root@linux-node1 ~]# scp kubernetes*.pem linux-node4:/opt/kubernetes/ssl/
```

### 3.创建加密配置文件

`ENCRYPTION_KEY`可以通过 `head -c 32 /dev/urandom | base64` 来生成;这里将ENCRYPTION_KEY改为`8eVtmpUpYjMvH8wKZtKCwQPqYRqM14yvtXPLJdhu0gA=`

```Bash
cat > /opt/kubernetes/ssl/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: 8eVtmpUpYjMvH8wKZtKCwQPqYRqM14yvtXPLJdhu0gA=
      - identity: {}
EOF

#将加密配置文件拷贝到 master 节点的 /opt/kubernetes/ssl/ 目录下
```

### 4.创建 metrics-server 使用的证书

- 创建 metrics-server 证书签名请求

```Bash
cat > /opt/kubernetes/ssl/metrics-server-csr.json <<EOF
{
  "CN": "aggregator",
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
      "OU": "4Paradigm"
    }
  ]
}
EOF
```
注意： CN 名称为 aggregator，需要与 kube-apiserver 的 --requestheader-allowed-names 参数配置一致
- 生成 metrics-server 证书和私钥

```Bash
cd /opt/kubernetes/ssl
/opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes metrics-server-csr.json | /opt/kubernetes/bin/cfssljson -bare metrics-server
```
- 将生成的证书和私钥文件拷贝到 kube-apiserver 节点

```Bash
scp metrics-server*.pem linux-node2:/opt/kubernetes/ssl/
scp metrics-server*.pem linux-node3:/opt/kubernetes/ssl/
```

### 5.部署Kubernetes API Server
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/opt/kubernetes/bin/kube-apiserver \
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --allow-privileged=true \
  --experimental-encryption-provider-config=/opt/kubernetes/ssl/encryption-config.yaml \
  --advertise-address=192.168.150.141 \
  --insecure-port=0 \
  --secure-port=6443 \
  --authorization-mode=Node,RBAC \
  --enable-bootstrap-token-auth=true \
  --service-cluster-ip-range=10.1.0.0/16 \
  --service-node-port-range=20000-40000 \
  --tls-cert-file=/opt/kubernetes/ssl/kubernetes.pem \
  --tls-private-key-file=/opt/kubernetes/ssl/kubernetes-key.pem \
  --client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --kubelet-client-certificate=/opt/kubernetes/ssl/kubernetes.pem \
  --kubelet-client-key=/opt/kubernetes/ssl/kubernetes-key.pem \
  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
  --service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --etcd-cafile=/opt/kubernetes/ssl/ca.pem \
  --etcd-certfile=/opt/kubernetes/ssl/kubernetes.pem \
  --etcd-keyfile=/opt/kubernetes/ssl/kubernetes-key.pem \
  --etcd-servers=https://192.168.150.141:2379,https://192.168.150.142:2379,https://192.168.150.143:2379 \
  --enable-swagger-ui=true \
  --max-mutating-requests-inflight=2000 \
  --max-requests-inflight=4000 \
  --requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --requestheader-allowed-names= \
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --proxy-client-cert-file=/opt/kubernetes/ssl/metrics-server.pem \
  --proxy-client-key-file=/opt/kubernetes/ssl/metrics-server-key.pem \
  --runtime-config=api/all=true \
  --apiserver-count=3 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/kube-apiserver-audit.log \
  --event-ttl=168h \
  --logtostderr=true \
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- `--experimental-encryption-provider-config`：启用加密特性
- `--authorization-mode=Node,RBAC`：开启 Node 和 RBAC 授权模式，拒绝未授权的请求
- `--enable-admission-plugins`：启用 ServiceAccount 和 NodeRestriction
- `--service-account-key-file`：签名 ServiceAccount Token 的公钥文件，kube-controller-manager 的 --service-account-private-key-file 指定私钥文件，两者配对使用
- `--tls-*-file`：指定 apiserver 使用的证书、私钥和 CA 文件。--client-ca-file 用于验证 client (kue-controller-manager、kube-scheduler、kubelet、kube-proxy 等)请求所带的证书。
- `--kubelet-client-certificate`、`--kubelet-client-key`：如果指定，则使用 https 访问 kubelet APIs；需要为证书对应的用户(上面 kubernetes*.pem 证书的用户为 kubernetes) 用户定义 RBAC 规则，否则访问 kubelet API 时提示未授权
- `--bind-address`：不能为 127.0.0.1，否则外界不能访问它的安全端口 6443
- `--insecure-port=0`：闭监听非安全端口(8080)
- `--service-cluster-ip-range`：指定 Service Cluster IP 地址段
- `--service-node-port-range`：指定 NodePort 的端口范围
- `--runtime-config=api/all=true`：启用所有版本的 APIs，如 autoscaling/v2alpha1
- `--enable-bootstrap-token-auth`：启用 kubelet bootstrap 的 token 认证
- `--apiserver-count=3`：指定集群运行模式，多台 kube-apiserver 会通过 leader 选举产生一个工作节点，其它节点处于阻塞状态

### 6.启动API Server服务
```Bash
#拷贝至其他主节点
[root@linux-node1 ~]#scp /usr/lib/systemd/system/kube-apiserver.service linux-node2:/usr/lib/systemd/system
[root@linux-node1 ~]#scp /usr/lib/systemd/system/kube-apiserver.service linux-node3:/usr/lib/systemd/system
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable kube-apiserver
[root@linux-node1 ~]# systemctl start kube-apiserver
```

查看API Server服务状态
```
[root@linux-node1 ~]# systemctl status kube-apiserver
```
### 7.打印 kube-apiserver 写入 etcd 的数据

```Bash
ETCDCTL_API=3 etcdctl \
    --endpoints=https://192.168.150.141:2379 \
    --cacert=/opt/kubernetes/ssl/ca.pem \
    --cert=/opt/kubernetes/ssl/etcd.pem \
    --key=/opt/kubernetes/ssl/etcd-key.pem \
    get /registry/ --prefix --keys-only
```
## 部署Kubectl命令行工具

- kubectl 是 kubernetes 集群的命令行管理工具，kubectl 默认从 `~/.kube/config` 文件读取 kube-apiserver 地址、证书、用户名等信息，如果没有配置，执行 kubectl 命令时可能会出错.
- 本文档只需要部署一次，生成的 kubeconfig 文件是通用的，可以拷贝到需要执行 kubeclt 命令的机器上。
- 将Kubectl的二进制文件拷贝到/opt/kubernetes/bin 目录下。

### 1. 创建 admin 证书和私钥

kubectl 与 apiserver https 安全端口通信，apiserver 对提供的证书进行认证和授权。

kubectl 作为集群的管理工具，需要被授予最高权限。这里创建具有最高权限的 admin 证书。

创建证书签名请求

```Bash
cd /opt/kubernetes/ssl
cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
```
- O 为 system:masters，kube-apiserver 收到该证书后将请求的 Group 设置为 system:masters
- 预定义的 ClusterRoleBinding cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予所有 API的权限
- 该证书只会被 kubectl 当做 client 证书使用，所以 hosts 字段为空

生成证书和私钥:

```Bash
cd /opt/kubernetes/ssl
/opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
 -ca-key=/opt/kubernetes/ssl/ca-key.pem \
 -config=/opt/kubernetes/ssl/ca-config.json \
 -profile=kubernetes admin-csr.json | /opt/kubernetes/bin/cfssljson -bare admin
ls admin*
```
创建 kubeconfig 文件

kubeconfig 为 kubectl 的配置文件，包含访问 apiserver 的所有信息，如 apiserver 地址、CA 证书和自身使用的证书

```Bash
cd /opt/kubernetes/cfg
# 设置集群参数
/opt/kubernetes/bin/kubectl config set-cluster kubernetes \
 --certificate-authority=/opt/kubernetes/ssl/ca.pem \
 --embed-certs=true --server=https://127.0.0.1:8443 \
 --kubeconfig=kubectl.kubeconfig
 # 设置客户端认证参数
/opt/kubernetes/bin/kubectl config set-credentials admin \
 --client-certificate=/opt/kubernetes/ssl/admin.pem \
 --embed-certs=true \
 --client-key=/opt/kubernetes/ssl/admin-key.pem \
 --kubeconfig=kubectl.kubeconfig
 #设置上下文参数
/opt/kubernetes/bin/kubectl config set-context kubernetes \
 --cluster=kubernetes \
 --user=admin \
 --kubeconfig=kubectl.kubeconfig
 #设置默认上下文
/opt/kubernetes/bin/kubectl config use-context kubernetes \
 --kubeconfig=kubectl.kubeconfig
#分发 kubeconfig 文件
mkdir -p ~/.kube && /bin/cp /opt/kubernetes/cfg/kubectl.kubeconfig ~/.kube/config
```
- --certificate-authority：验证 kube-apiserver 证书的根证书
- --client-certificate、--client-key：刚生成的 admin 证书和私钥，连接 kube-apiserver 时使用
- --embed-certs=true：将 ca.pem 和 admin.pem 证书内容嵌入到生成的 kubectl.kubeconfig 文件中(不加时，写入的是证书文件路径)


## 部署Controller Manager服务
- 该集群包含 3 个节点，启动后将通过竞争选举机制产生一个 leader 节点，其它节点为阻塞状态。当 leader 节点不可用后，剩余节点将再次进行选举产生新的 leader 节点，从而保证服务的可用性
- 为保证通信安全，本文档先生成 x509 证书和私钥，kube-controller-manager 在如下两种情况下使用该证书

1. 与 kube-apiserver 的安全端口通信时
2. 在安全端口(https，10252) 输出 prometheus 格式的 metrics

### 1.创建 kube-controller-manager 证书和私钥
创建证书签名请求:
```Bash
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "192.168.150.141",
      "192.168.150.142",
      "192.168.150.143"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-controller-manager",
        "OU": "System"
      }
    ]
}
```
- hosts 列表包含所有 kube-controller-manager 节点 IP
- CN 为 system:kube-controller-manager、O 为 system:kube-controller-manager，kubernetes 内置的 ClusterRoleBindings system:kube-controller-manager 赋予 kube-controller-manager 工作所需的权限

生成证书和私钥:
```Bash
cd /opt/kubernetes/ssl
/opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
 -ca-key=/opt/kubernetes/ssl/ca-key.pem \
 -config=/opt/kubernetes/ssl/ca-config.json \
 -profile=kubernetes kube-controller-manager-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-controller-manager

ls kube-controller-manager*pem
```
将生成的证书和私钥分发到所有 master 节点:
```Bash
scp kube-controller-manager*.pem linux-node2:/opt/kubernetes/ssl/
scp kube-controller-manager*.pem linux-node3:/opt/kubernetes/ssl/
```
### 2.创建和分发 kubeconfig 文件

kubeconfig 文件包含访问 apiserver 的所有信息，如 apiserver 地址、CA 证书和自身使用的证书

```Bash
cd /opt/kubernetes/cfg
/opt/kubernetes/bin/kubectl config set-cluster kubernetes \
 --certificate-authority=/opt/kubernetes/ssl/ca.pem \
 --embed-certs=true \
 --server=https://127.0.0.1:8443 \
 --kubeconfig=kube-controller-manager.kubeconfig

/opt/kubernetes/bin/kubectl config set-credentials system:kube-controller-manager \
 --client-certificate=/opt/kubernetes/ssl/kube-controller-manager.pem \
 --embed-certs=true \
 --client-key=/opt/kubernetes/ssl/kube-controller-manager-key.pem \
 --kubeconfig=kube-controller-manager.kubeconfig

/opt/kubernetes/bin/kubectl config set-context system:kube-controller-manager \
 --cluster=kubernetes \
 --user=system:kube-controller-manager \
 --kubeconfig=kube-controller-manager.kubeconfig

/opt/kubernetes/bin/kubectl config use-context system:kube-controller-manager \
 --kubeconfig=kube-controller-manager.kubeconfig
```
分发 kubeconfig 到所有 master 节点:

```Bash
scp kube-controller-manager.kubeconfig linux-node2:/opt/kubernetes/cfg/
scp kube-controller-manager.kubeconfig linux-node3:/opt/kubernetes/cfg/
```
### 3.创建和分发 kube-controller-manager systemd unit 文件
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --allocate-node-cidrs=true \
  --authentication-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --authorization-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --service-cluster-ip-range=10.1.0.0/16 \
  --cluster-cidr=10.2.0.0/16 \
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \
  --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --leader-elect=true \
  --feature-gates=RotateKubeletServerCertificate=true \
  --controllers=*,bootstrapsigner,tokencleaner \
  --horizontal-pod-autoscaler-use-rest-clients=true \
  --horizontal-pod-autoscaler-sync-period=10s \
  --tls-cert-file=/opt/kubernetes/ssl/kube-controller-manager.pem \
  --tls-private-key-file=/opt/kubernetes/ssl/kube-controller-manager-key.pem \
  --use-service-account-credentials=true \
  --logtostderr=true \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```
- --port=0：关闭监听 http /metrics 的请求，同时 --address 参数无效，--bind-address 参数有效
- --secure-port=10252、--bind-address=0.0.0.0: 在所有网络接口监听 10252 端口的 https /metrics 请求
- --kubeconfig：指定 kubeconfig 文件路径，kube-controller-manager 使用它连接和验证 kube-apiserver
- --authentication-kubeconfig 和 --authorization-kubeconfig：kube-controller-manager 使用它连接 apiserver，对 client 的请求进行认证和授权。kube-controller-manager 不再使用 --tls-ca-file 对请求 https metrics 的 Client 证书进行校验。如果没有配置这两个 kubeconfig 参数，则 client 连接 kube-controller-manager https 端口的请求会被拒绝(提示权限不足)。
- --cluster-signing-*-file：签名 TLS Bootstrap 创建的证书
- --experimental-cluster-signing-duration：指定 TLS Bootstrap 证书的有效期
- --root-ca-file：放置到容器 ServiceAccount 中的 CA 证书，用来对 kube-apiserver 的证书进行校验
- --service-account-private-key-file：签名 ServiceAccount 中 Token 的私钥文件，必须和 kube-apiserver 的 --service-account-key-file 指定的公钥文件配对使用
- --service-cluster-ip-range ：指定 Service Cluster IP 网段，必须和 kube-apiserver 中的同名参数一致
- --leader-elect=true：集群运行模式，启用选举功能；被选为 leader 的节点负责处理工作，其它节点为阻塞状态
- --controllers=*,bootstrapsigner,tokencleaner：启用的控制器列表，tokencleaner 用于自动清理过期的 Bootstrap token；
- --horizontal-pod-autoscaler-*：custom metrics 相关参数，支持 autoscaling/v2alpha1
- --tls-cert-file、--tls-private-key-file：使用 https 输出 metrics 时使用的 Server 证书和秘钥
- --use-service-account-credentials=true: kube-controller-manager 中各 controller 使用 serviceaccount 访问 kube-apiserver

分发 systemd unit 文件到所有 master 节点

```Bash
scp /usr/lib/systemd/system/kube-controller-manager.service linux-node2:/usr/lib/systemd/system/
scp /usr/lib/systemd/system/kube-controller-manager.service linux-node3:/usr/lib/systemd/system/
```
### 4.kube-controller-manager 的权限

ClusteRole: system:kube-controller-manager 的权限很小，只能创建 secret、serviceaccount 等资源对象，各 controller 的权限分散到 ClusterRole system:controller:XXX 中

需要在 kube-controller-manager 的启动参数中添加 --use-service-account-credentials=true 参数，这样 main controller 会为各 controller 创建对应的 ServiceAccount XXX-controller。

内置的 ClusterRoleBinding system:controller:XXX 将赋予各 XXX-controller ServiceAccount 对应的 ClusterRole system:controller:XXX 权限。

另外，--authentication-kubeconfig 和 --authorization-kubeconfig 参数指定的证书需要有创建 "subjectaccessreviews" 的权限，否则提示：

```Bash
$ curl --cacert /opt/k8s/work/ca.pem --cert /opt/k8s/work/admin.pem --key /opt/k8s/work/admin-key.pem https://127.0.0.1:10252/metrics

Internal Server Error: "/metrics": subjectaccessreviews.authorization.k8s.io is forbidden: User "system:kube-controller-manager" cannot create resource "subjectaccessreviews" in API group "authorization.k8s.io" at the cluster scope
```
解决办法是创建一个 ClusterRoleBinding，赋予相应的权限

```Bash
$ kubectl create clusterrolebinding controller-manager:system:auth-delegator --user system:kube-controller-manager --clusterrole system:auth-delegator
clusterrolebinding.rbac.authorization.k8s.io/controller-manager:system:auth-delegator created
```
参考：https://github.com/kubernetes/kubeadm/issues/1285
### 5.启动Controller Manager
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 scripts]# systemctl enable kube-controller-manager
[root@linux-node1 scripts]# systemctl start kube-controller-manager
```

### 6.查看服务状态
```
[root@linux-node1]# systemctl status kube-controller-manager
[root@linux-node1]# journalctl -u kube-controller-manager

```

## 部署Kubernetes Scheduler

- 该集群包含 3 个节点，启动后将通过竞争选举机制产生一个 leader 节点，其它节点为阻塞状态。当 leader 节点不可用后，剩余节点将再次进行选举产生新的 leader 节点，从而保证服务的可用性
- 在安全端口(https，10251) 输出 prometheus 格式的 metrics
- 与 kube-apiserver 的安全端口通信

### 1.创建 kube-scheduler 证书和私钥

创建证书签名请求:

```Bash
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
      "192.168.150.141",
      "192.168.150.142",
      "192.168.150.143"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-scheduler",
        "OU": "System"
      }
    ]
}
```
- hosts 列表包含所有 kube-scheduler 节点 IP
- CN 为 system:kube-scheduler、O 为 system:kube-scheduler，kubernetes 内置的 ClusterRoleBindings system:kube-scheduler 将赋予 kube-scheduler 工作所需的权限.

生成证书和私钥:

```Bash
cd /opt/kubernetes/ssl
/opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
 -ca-key=/opt/kubernetes/ssl/ca-key.pem \
 -config=/opt/kubernetes/ssl/ca-config.json \
 -profile=kubernetes kube-scheduler-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-scheduler
ls kube-scheduler*pem
```
### 2.创建和分发 kubeconfig 文件

kubeconfig 文件包含访问 apiserver 的所有信息，如 apiserver 地址、CA 证书和自身使用的证书

```Bash
cd /opt/kubernetes/cfg
/opt/kubernetes/bin/kubectl config set-cluster kubernetes \
 --certificate-authority=/opt/kubernetes/ssl/ca.pem \
 --embed-certs=true \
 --server=https://127.0.0.1:8443 \
 --kubeconfig=kube-scheduler.kubeconfig

/opt/kubernetes/bin/kubectl config set-credentials system:kube-scheduler \
 --client-certificate=/opt/kubernetes/ssl/kube-scheduler.pem \
 --embed-certs=true \
 --client-key=/opt/kubernetes/ssl/kube-scheduler-key.pem \
 --kubeconfig=kube-scheduler.kubeconfig

/opt/kubernetes/bin/kubectl config set-context system:kube-scheduler \
 --cluster=kubernetes \
 --user=system:kube-scheduler \
 --kubeconfig=kube-scheduler.kubeconfig

/opt/kubernetes/bin/kubectl config use-context system:kube-scheduler \
 --kubeconfig=kube-scheduler.kubeconfig
```
- 上一步创建的证书、私钥以及 kube-apiserver 地址被写入到 kubeconfig 文件中

分发 kubeconfig 到所有 master 节点:

```Bash
scp kube-scheduler.kubeconfig linux-node2:/opt/kubernetes/cfg/
scp kube-scheduler.kubeconfig linux-node3:/opt/kubernetes/cfg/
```
### 3.创建和分发 kube-scheduler systemd unit 文件

```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-scheduler \
  --leader-elect=true \
  --address=127.0.0.1 \
  --kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \
  --logtostderr=true \
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
```
- --kubeconfig：指定 kubeconfig 文件路径，kube-scheduler 使用它连接和验证 kube-apiserver
- --leader-elect=true：集群运行模式，启用选举功能；被选为 leader 的节点负责处理工作，其它节点为阻塞状态

### 4.启动 kube-scheduler 服务
```Bash
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable kube-scheduler
[root@linux-node1 ~]# systemctl start kube-scheduler
[root@linux-node1 ~]# systemctl status kube-scheduler
[root@linux-node1 ~]# journalctl -u kube-scheduler
```
### 5.查看输出的 metric

```Bash
$ curl -s https://127.0.0.1:10251/metrics |head
# HELP apiserver_audit_event_total Counter of audit events generated and sent to the audit backend.
# TYPE apiserver_audit_event_total counter
apiserver_audit_event_total 0
# HELP go_gc_duration_seconds A summary of the GC invocation durations.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 9.7715e-05
go_gc_duration_seconds{quantile="0.25"} 0.000107676
go_gc_duration_seconds{quantile="0.5"} 0.00017868
go_gc_duration_seconds{quantile="0.75"} 0.000262444
go_gc_duration_seconds{quantile="1"} 0.001205223
```

### 6.测试 kube-scheduler 集群的高可用

```Bash
#随便找一个或两个 master 节点，停掉 kube-scheduler 服务，看其它节点是否获取了 leader 权限（systemd 日志）
$ kubectl get endpoints kube-scheduler --namespace=kube-system  -o yaml
apiVersion: v1
kind: Endpoints
metadata:
  annotations:
    control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"m7-autocv-gpu01_7295c239-f2e9-11e8-8b5d-0cc47a2afc6a","leaseDurationSeconds":15,"acquireTime":"2018-11-28T08:41:50Z","renewTime":"2018-11-28T08:42:08Z","leaderTransitions":0}'
  creationTimestamp: 2018-11-28T08:41:50Z
  name: kube-scheduler
  namespace: kube-system
  resourceVersion: "1013"
  selfLink: /api/v1/namespaces/kube-system/endpoints/kube-scheduler
  uid: 73305545-f2e9-11e8-b65b-0cc47a2afc6a
```

## 以上所有的步骤需要在Master上执行。如果需要master也参与集群节点。需要继续部署node节点上的服务。
