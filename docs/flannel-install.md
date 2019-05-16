## 部署flannel

### 1.创建相关配置目录

```bash
mkdir /etc/kube-flannel
```

### 2.下载Flannel软件包
```Bash
[root@linux-node1 ~]# cd /usr/local/src
# wget
 https://github.com/coreos/flannel/releases/download/v0.11.0/flannel-v0.11.0-linux-amd64.tar.gz
[root@linux-node1 src]# tar zxf flannel-v0.10.0-linux-amd64.tar.gz
[root@linux-node1 src]# cp flanneld /opt/kubernetes/bin/
复制到linux-node2节点
[root@linux-node1 src]# scp flanneld linux-node2:/opt/kubernetes/bin/
[root@linux-node1 src]# scp flanneld linux-node3:/opt/kubernetes/bin/
[root@linux-node1 src]# scp flanneld linux-node4:/opt/kubernetes/bin/
```

### 3.创建flannel的配置文件
```
[root@linux-node1 ~]# cat /etc/kube-flannel/net-conf.json
{
  "Network": "10.2.0.0/16",
  "Backend": {
    "Type": "vxlan"
  }
}
```
### 4. 生成flannel的kubeconfig配置文件flanneld.kubeconfig

```bash
[root@linux-node1 ~]# cat /opt/kubernetes/bin/flannelkubeconfig.sh
#!/bin/bash
#配置flannel走kube-apiserver，调用etcd
/usr/bin/cat << EOF | /opt/kubernetes/bin/kubectl apply -f -
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
rules:
  - apiGroups: ['extensions']
    resources: ['podsecuritypolicies']
    verbs: ['use']
    resourceNames: ['psp.flannel.unprivileged']
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
EOF

CLUSTER_NAME="kubernetes"
KUBE_CONFIG="flanneld.kubeconfig"
KUBE_APISERVER=https://127.0.0.1:8443

SECRET=$(/opt/kubernetes/bin/kubectl -n kube-system get ServiceAccount/flannel \
    --output=jsonpath='{.secrets[0].name}')

JWT_TOKEN=$(/opt/kubernetes/bin/kubectl -n kube-system get secret/$SECRET \
    --output=jsonpath='{.data.token}' | base64 -d)

/opt/kubernetes/bin/kubectl config set-cluster ${CLUSTER_NAME} \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=/opt/kubernetes/cfg/${KUBE_CONFIG}

/opt/kubernetes/bin/kubectl config set-context ${CLUSTER_NAME} \
  --cluster=${CLUSTER_NAME} \
  --user=${CLUSTER_NAME} \
  --kubeconfig=/opt/kubernetes/cfg/${KUBE_CONFIG}

/opt/kubernetes/bin/kubectl config set-credentials ${CLUSTER_NAME} --token=${JWT_TOKEN} --kubeconfig=/opt/kubernetes/cfg/${KUBE_CONFIG}

/opt/kubernetes/bin/kubectl config use-context ${CLUSTER_NAME} --kubeconfig=/opt/kubernetes/cfg/${KUBE_CONFIG}

/opt/kubernetes/bin/kubectl config view --kubeconfig=/opt/kubernetes/cfg/${KUBE_CONFIG}
#添加执行权限
[root@linux-node1 ~]# chmod +x /opt/kubernetes/bin/flannelkubeconfig.sh
[root@linux-node1 ~]# /bin/bash /opt/kubernetes/bin/flannelkubeconfig.sh
```
分发flanneld.kubeconfig配置文件到所有节点。

### 5.设置Flannel系统服务

```Bash
[root@linux-node1 ~]# cat /usr/lib/systemd/system/flannel.service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
# This is needed because of this: https://github.com/coreos/flannel/issues/792
# Kubernetes knows the nodes by their FQDN so we have to use the FQDN
#Environment=NODE_NAME=my-node.foo.bar.com
# Note that we don't specify any etcd option. This is because we want to talk
# to the apiserver instead. The apiserver then talks to etcd on flannel's
# behalf.
Environment=NODE_NAME=linux-node1
ExecStart=/opt/kubernetes/bin/flanneld \
  --kube-subnet-mgr=true \
  --kubeconfig-file=/opt/kubernetes/cfg/flanneld.kubeconfig \
  --ip-masq=true \
  --iface=ens32 \
  --public-ip=192.168.150.141 \
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0
Type=notify

[Install]
WantedBy=multi-user.target
```

启动flannel

```Bash
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable flannel
[root@linux-node1 ~]# chmod +x /opt/kubernetes/bin/*
[root@linux-node1 ~]# systemctl start flannel
```

查看服务状态
```Bash
[root@linux-node1 ~]# systemctl status flannel
```
