## 部署Kubernetes API服务部署
### 0.准备软件包
```
[root@linux-node1 ~]# cd /usr/local/src/kubernetes
[root@linux-node1 kubernetes]# cp server/bin/kube-apiserver /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-controller-manager /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-scheduler /opt/kubernetes/bin/
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
## 部署Kubectl

## 部署Controller Manager服务
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --allocate-node-cidrs=true \
  --service-cluster-ip-range=10.1.0.0/16 \
  --cluster-cidr=10.2.0.0/16 \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \
  --leader-elect=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3.启动Controller Manager
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 scripts]# systemctl enable kube-controller-manager
[root@linux-node1 scripts]# systemctl start kube-controller-manager
```

## 4.查看服务状态
```
[root@linux-node1 scripts]# systemctl status kube-controller-manager
```

## 部署Kubernetes Scheduler
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-scheduler \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --leader-elect=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2.部署服务
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 scripts]# systemctl enable kube-scheduler
[root@linux-node1 scripts]# systemctl start kube-scheduler
[root@linux-node1 scripts]# systemctl status kube-scheduler
```

## 部署kubectl 命令行工具

1.准备二进制命令包
```
[root@linux-node1 ~]# cd /usr/local/src/kubernetes/client/bin
[root@linux-node1 bin]# cp kubectl /opt/kubernetes/bin/
```

2.创建 admin 证书签名请求
```
[root@linux-node1 ~]# cd /usr/local/src/ssl/
[root@linux-node1 ssl]# vim admin-csr.json
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
```

3.生成 admin 证书和私钥：
```
[root@linux-node1 ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes admin-csr.json | cfssljson -bare admin
[root@linux-node1 ssl]# ls -l admin*
-rw-r--r-- 1 root root 1009 Mar  5 12:29 admin.csr
-rw-r--r-- 1 root root  229 Mar  5 12:28 admin-csr.json
-rw------- 1 root root 1675 Mar  5 12:29 admin-key.pem
-rw-r--r-- 1 root root 1399 Mar  5 12:29 admin.pem

[root@linux-node1 src]# mv admin*.pem /opt/kubernetes/ssl/
```

4.设置集群参数
```
[root@linux-node1 src]# kubectl config set-cluster kubernetes \
   --certificate-authority=/opt/kubernetes/ssl/ca.pem \
   --embed-certs=true \
   --server=https://192.168.56.11:6443
Cluster "kubernetes" set.
```

5.设置客户端认证参数
```
[root@linux-node1 src]# kubectl config set-credentials admin \
   --client-certificate=/opt/kubernetes/ssl/admin.pem \
   --embed-certs=true \
   --client-key=/opt/kubernetes/ssl/admin-key.pem
User "admin" set.
```

6.设置上下文参数
```
[root@linux-node1 src]# kubectl config set-context kubernetes \
   --cluster=kubernetes \
   --user=admin
Context "kubernetes" created.
```

7.设置默认上下文
```
[root@linux-node1 src]# kubectl config use-context kubernetes
Switched to context "kubernetes".
```

8.使用kubectl工具
```
[root@linux-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```
