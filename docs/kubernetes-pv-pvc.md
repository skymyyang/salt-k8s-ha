## 存储卷

- emptyDir
- hostPath
- NAS（网络接入存储Network-Attached Storage）：NAS存储就是存储设备通过标准的网络拓扑结构(比如以太网)添加到一群计算机上。与DAS以及SAN不同，NAS是文件级的存储方法。采用NAS较多的功能是用来进行文件共享。nfs，cifs
- SAN（存储区域网络Storage Area Network）：通过光纤通道交换机连接存储阵列和服务器主机，最后成为一个专用的存储网络,SAN解决方案通常会采取以下两种形式：光纤信道以及iSCSI或者基于IP的SAN，也就是FC SAN和IP SAN。iSCSI.
- 分布式存储： glusterFS RBD cephFS
- 云存储：EBS Azure Disk

### emptyDir

emptyDir的生命周期同pod。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: www
      mountPath: /data/
    command: ['/bin/sh']
    args: ["-c", "while true; do echo $(date) >> /data/index.html; sleep 2; done"]
  volumes:
  - name: www
    emptyDir: {}
```
### hostPath

宿主机路径，将节点上的某一目录挂载到容器内部。不支持跨节点的重新调度。如果节点宕机的话，将会到导致数据丢失。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-hostpath
  namespace: default
  labels:
    app: pod-vol-hostpath
    tier: hostpath
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: www
    hostPath:
      path: /data/pod/volume1
      type: DirectoryOrCreate
```
### NFS
NFS可以保证数据的持久性。
1. 安装NFS

```bash
yum install nfs-utils -y
mkdir /data/volumes -p
cat /etc/exports
/data/volumes 192.168.200.0/24(rw,no_root_squash)
mkdir /data/volumes/v{1,2,3,4,5,6}
exportfs -arv
showmount -e
```
2. yaml示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-nfs
  namespace: default
  labels:
    app: pod-vol-nfs
    tier: hostpath
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: www
    nfs:
      path: /data/volumes
      server: 172.16.18.86
```

## PV 和 PVC
PersistentVolume（pv）和PersistentVolumeClaim（pvc）是k8s提供的两种API资源，用于抽象存储细节。管理员关注于如何通过pv提供存储功能而无需
关注用户如何使用，同样的用户只需要挂载pvc到容器中而不需要关注存储卷采用何种技术实现。
pvc和pv的关系与pod和node关系类似，前者消耗后者的资源。pvc可以向pv申请指定大小的存储资源并设置访问模式,这就可以通过Provision -> Claim 的方式，来对存储资源进行控制。



pv的定义

```yaml
kind: PersistentVolume
metadata:
  name: pv001
  labels:
    name: pv001
spec:
  nfs:
    path: /data/volumes/v1
    server: 172.16.18.86
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 5Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv002
  labels:
    name: pv002
spec:
  nfs:
    path: /data/volumes/v2
    server: 172.16.18.86
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 5Gi
```

pvc的定义

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc1
  namespace: default
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 6Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-pvc
  namespace: default
  labels:
    app: pod-vol-pvc
    tier: pvc
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: www
    persistentVolumeClaim:
      claimName: mypvc1
```


## StrongeClass（存储类）

### RBD-StrongeClass
是一种标准的k8s资源。支持动态申请PV的功能。
这里我们将使用ceph为k8s提供动态申请PV的功能。ceph提供底层存储的功能，cephfs方式支持k8s的pv的3中访问模式，ReadWriteOnce，ReadOnlyMany ，ReadWriteMany,RBD支持ReadWriteOnce，ReadOnlyMany两种模式。

访问模式只是能力描述，并不是强制执行的，对于没有按pvc声明的方式使用pv，存储提供者应该负责访问时的运行错误。例如如果设置pvc的访问模式为ReadOnlyMany ，pod挂载后依然可写，如果需要真正的不可写，申请pvc是需要指定 readOnly: true 参数

1. 使用kubeadm安装集群的额外配置

 - 如果使用kubeadm部署的集群需要这些额外的步骤
 - 由于使用动态存储时 controller-manager 需要使用 rbd 命令创建 image
 - 所以 controller-manager 需要使用 rbd 命令
 - 由于官方controller-manager镜像里没有rbd命令
 - 如果没使用如下方式会报错无法成功创建pvc
 - 相关 issue https://github.com/kubernetes/kubernetes/issues/38923

```bash
cat >external-storage-rbd-provisioner.yaml<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-provisioner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services"]
    resourceNames: ["kube-dns"]
    verbs: ["list", "get"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-provisioner
subjects:
  - kind: ServiceAccount
    name: rbd-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: rbd-provisioner
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rbd-provisioner
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rbd-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rbd-provisioner
subjects:
- kind: ServiceAccount
  name: rbd-provisioner
  namespace: kube-system

---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: rbd-provisioner
  namespace: kube-system
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: rbd-provisioner
    spec:
      containers:
      - name: rbd-provisioner
        image: "quay.io/external_storage/rbd-provisioner:latest"
        env:
        - name: PROVISIONER_NAME
          value: ceph.com/rbd
      serviceAccount: rbd-provisioner
EOF
kubectl apply -f external-storage-rbd-provisioner.yaml
# 查看状态 等待running之后 再进行后续的操作
kubectl get pod -n kube-system
```
2. 配置 storageclass

```bash
#在k8s集群中所有节点安装ceph-common,必须跟ceph的版本保持一致。
#配置cephyum源
cat > /etc/yum.repos.d/ceph.repo << EOF
[Ceph]
name=Ceph packages for $basearch
baseurl=http://mirrors.aliyun.com/ceph/rpm-luminous/el7/$basearch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://mirrors.aliyun.com/ceph/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://mirrors.aliyun.com/ceph/rpm-luminous/el7/noarch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://mirrors.aliyun.com/ceph/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://mirrors.aliyun.com/ceph/rpm-luminous/el7/SRPMS
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://mirrors.aliyun.com/ceph/keys/release.asc
priority=1
EOF
yum install -y ceph-common
#创建secret
#获取key
ceph auth get-key client.admin | base64
QVFCdDlXaGRVTE1US2hBQWQzUnR1MlY0MWkyc2luVFlodXZBcVE9PQ==
cat > ceph-secret-kubesystem.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
  namespace: kube-system
type: "kubernetes.io/rbd"
data:
  key: QVFCdDlXaGRVTE1US2hBQWQzUnR1MlY0MWkyc2luVFlodXZBcVE9PQ==
EOF

cat > ceph-user-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-user-secret
  namespace: default
type: "kubernetes.io/rbd"
data:
  key: QVFCdDlXaGRVTE1US2hBQWQzUnR1MlY0MWkyc2luVFlodXZBcVE9PQ==
EOF
# 配置storageclass
cat >storageclass-ceph-rdb.yaml<<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: fast
provisioner: ceph.com/rbd
#provisioner: kubernetes.io/rbd
parameters:
  monitors: 172.16.40.172:6789,172.16.40.203:6789,172.16.40.21:6789
  adminId: admin
  adminSecretName: ceph-secret
  adminSecretNamespace: kube-system
  pool: rbd2 #此处默认是rbd池，生产上建议自己创建存储池隔离
  userId: admin
  userSecretName: ceph-user-secret
  fsType: xfs
  imageFormat: "2"
  imageFeatures: "layering"
EOF
kubectl apply -f storageclass-ceph-rdb.yaml
kubectl get sc
```

3. 测试使用

```bash
cat > ceph-rdb-pvc-test.yaml << EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: rbd-pvc-pod-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
  storageClassName: fast
EOF
kubectl apply -f ceph-rdb-pvc-test.yaml
# 查看
kubectl get pvc
kubectl get pv
#挂载POD测试
cat > pod-demo-ceph.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-rbd
  namespace: default
  labels:
    app: pod-vol-rbd
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: www
    persistentVolumeClaim:
      claimName: rbd-pvc-pod-pvc
EOF
kubectl exec -ti pod-vol-rbd -- /bin/sh -c 'echo Hello World from Ceph RBD!!! > /usr/share/nginx/html/index.html'

# 访问测试
POD_ID=$(kubectl get pods -o wide | grep nginx-pod1 | awk '{print $(NF-1)}')
curl http://$POD_ID
```

### CephFS-StrongeClasee

1. 部署cephfs-provisioner

```bash
# 官方没有cephfs动态卷支持
# 使用社区提供的cephfs-provisioner
cat >external-storage-cephfs-provisioner.yaml<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cephfs-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
subjects:
  - kind: ServiceAccount
    name: cephfs-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cephfs-provisioner
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cephfs-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cephfs-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cephfs-provisioner
subjects:
- kind: ServiceAccount
  name: cephfs-provisioner
  namespace: kube-system

---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: cephfs-provisioner
  namespace: kube-system
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: cephfs-provisioner
    spec:
      containers:
      - name: cephfs-provisioner
        image: "quay.io/external_storage/cephfs-provisioner:latest"
        env:
        - name: PROVISIONER_NAME
          value: ceph.com/cephfs
        command:
        - "/usr/local/bin/cephfs-provisioner"
        args:
        - "-id=cephfs-provisioner-1"
      serviceAccount: cephfs-provisioner
EOF

kubectl apply -f external-storage-cephfs-provisioner.yaml
```
2. 配置存储类(strogeclass)

```bash
#配置secret，如果rbd配置之后可以跳过此步骤
cat > cephfs-admin-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
  namespace: kube-system
type: "kubernetes.io/rbd"
data:
  key: QVFCdDlXaGRVTE1US2hBQWQzUnR1MlY0MWkyc2luVFlodXZBcVE9PQ==
EOF
#配置storageclass
cat > storageclass-cephfs.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: dynamic-cephfs
provisioner: ceph.com/cephfs
parameters:
    monitors: 172.16.40.172:6789,172.16.40.203:6789,172.16.40.21:6789
    adminId: admin
    adminSecretName: ceph-secret
    adminSecretNamespace: "kube-system"
    claimRoot: /volumes/kubernetes
EOF
# 创建
kubectl apply -f storageclass-cephfs.yaml

# 查看
kubectl get sc
```
3. 测试使用

```bash
# 创建pvc测试
cat >cephfs-pvc-test.yaml<<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cephfs-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: dynamic-cephfs
  resources:
    requests:
      storage: 2Gi
EOF
kubectl apply -f cephfs-pvc-test.yaml
# 查看
kubectl get pvc
kubectl get pv
# 创建 nginx pod 挂载测试
cat >nginx-pod.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod1
  labels:
    name: nginx-pod1
spec:
  containers:
  - name: nginx-pod1
    image: nginx:alpine
    ports:
    - name: web
      containerPort: 80
    volumeMounts:
    - name: cephfs
      mountPath: /usr/share/nginx/html
  volumes:
  - name: cephfs
    persistentVolumeClaim:
      claimName: cephfs-claim
EOF
kubectl apply -f nginx-pod.yaml

# 查看
kubectl get pods -o wide

# 修改文件内容
kubectl exec -ti nginx-pod1 -- /bin/sh -c 'echo Hello World from CephFS!!! > /usr/share/nginx/html/index.html'

# 访问测试
POD_ID=$(kubectl get pods -o wide | grep nginx-pod1 | awk '{print $(NF-1)}')
curl http://$POD_ID

# 清理
kubectl delete -f nginx-pod.yaml
kubectl delete -f cephfs-pvc-test.yaml
```


### NFS-StrongClass

1. 安装nfs server
  
   ```bash
   yum install nfs-utils rpcbind -y
   ```
2. 编辑/etc/exports，并启动nfs
   ```bash
   vim /etc/exports
   /data 192.168.200.0/24(rw,sync,no_root_squash,no_all_squash)
   systemctl start nfs && systemctl enable nfs
   # 如若后续遇到权限问题，可以直接赋予目录777的权限
   # chmod 777 /data/ -R
   ```
3. 安装并配置nfs插件客户端
  
    官网地址：https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client
    
    下载rbac.yaml deployment.yaml两个文件，进行部署,本人使用的是k8sv1.14.7 kubeadm部署，官网的sa权限是有问题的，这里我们进行修改，修改之后的文件如下：
    
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["watch, ""create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get","create","list", "watch","update"]
  - apiGroups: ["extensions"]
    resources: ["podsecuritypolicies"]
    resourceNames: ["nfs-client-provisioner"]
    verbs: ["use"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: skymyyang/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs
            - name: NFS_SERVER
              value: 192.168.200.131
            - name: NFS_PATH
              value: /data
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.200.131
            path: /data
```

4. 定义存储类
   存储类是不区分名称空间。这里我们定义一个harbor的存储类，便于我们在k8s集群中安装harbor。

   `$ cat harbor-data-sc.yaml`

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: harbor-data
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "false"
```

5. 测试验证
   定义一个PV进行相关测试

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: rbd-pvc-pod-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
  storageClassName: harbor-data
```

6. 删除步骤

   ```shell
   #删除的时候先删除pvc 再删除pv  但是删除之前建议先备份数据
   #pvc 是有名称空间之分的，pv是不区分名称空间的
   kubectl delete pvc prometheus-k8s-db-prometheus-k8s-0 -n monitoring
   kubectl delete pv pvc-53bbc26c-0113-11ea-a016-00505682b6ba
   ```

   