## 基于kubernetes部署Jenkins并支持动态slave
### 写在前面的话
之前使用Jenkins来做为CI/CD工具，部署maven以及Node.JS项目，没有使用pipeline，使用的是最为原始的GUI填写的方式进行项目的部署。导致我们需要为每个环境Dev、Test、Pre、Pro分别部署一套Jenkins。而且都是单节点的，随着项目的增多，导致管理越来越混乱，出现了很多问题。因此我们打算优化我们的CI/CD流程，使用Kubernetes、Jenkins集群以及Blue Ocean。
### 安装
1. 创建rbac相关的资源对象
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: kube-ops
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: jenkins
rules:
  - apiGroups: ["extensions", "apps"]
    resources: ["deployments"]
    verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create","delete","get","list","patch","update","watch"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create","delete","get","list","patch","update","watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get","list","watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: jenkins
  namespace: kube-ops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins
subjects:
  - kind: ServiceAccount
    name: jenkins
    namespace: kube-ops
```
2. 创建Jenkins所需的存储卷
   
   这里我们选择了我们之前构建的ceph集群的rbd存储的存储类。详情可参考如下链接：
   - ceph安装部署: `https://iokubernetes.github.io/2019/09/11/ceph%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2/`
   - kubernetes pv pvc: `https://github.com/skymyyang/salt-k8s-ha/blob/master/docs/kubernetes-pv-pvc.md`
   
   这里注意需要创建kube-ops名称空间下所需要的访问ceph-rbd的secret。
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-rbd-pvc
  namespace: kube-ops
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast
```
3. 构建Jenkins statefulset应用
   
```yaml
---
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: jenkins
  namespace: kube-ops
  labels:
    app: jenkins
spec:
  serviceName: jenkins-svc
  replicas: 1
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      name: jenkins
      labels:
        app: jenkins
    spec:
      terminationGracePeriodSeconds: 10
      serviceAccountName: jenkins
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: web
          protocol: TCP
        - containerPort: 50000
          name: agent
          protocol: TCP
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /login
            port: 8080
          initialDelaySeconds: 60
          timeoutSeconds: 5
          failureThreshold: 12
        readinessProbe:
          httpGet:
            path: /login
            port: 8080
          initialDelaySeconds: 60
          timeoutSeconds: 5
          failureThreshold: 12
        volumeMounts:
        - name: jenkinshome
          subPath: jenkins
          mountPath: /var/jenkins_home
        env:
        - name: LIMITS_MEMORY
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: 1Mi
        - name: JAVA_OPTS
          value: -Xmx$(LIMITS_MEMORY)m -XshowSettings:vm -Dhudson.slaves.NodeProvisioner.initialDelay=0 -Dhudson.slaves.NodeProvisioner.MARGIN=50 -Dhudson.slaves.NodeProvisioner.MARGIN0=0.85 -Duser.timezone=Asia/Shanghai
      securityContext:
        fsGroup: 1000
      volumes:
      - name: jenkinshome
        persistentVolumeClaim:
          claimName: jenkins-rbd-pvc
```
4. 创建Jenkins svc 以及ingress 暴露致外网访问。

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-svc
  namespace: kube-ops
  labels:
    app: jenkins-svc
spec:
  selector:
    app: jenkins
  clusterIP: None
  ports:
    - name: http
      port: 8080
      targetPort: 8080
    - name: agent
      port: 50000
      targetPort: 50000
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: jenkins-svc-ingress
  namespace: kube-ops
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: jenkins.mofangge.net
      http:
        paths:
        - backend:
            serviceName: jenkins-svc
            servicePort: 8080
```
5. 此时我们访问 jenkins.mofangge.net 进行测试。会提示你输入密码，密码可以通过日志进行查看。
   
```bash
$kubectl logs -f jenkins-0 -n kube-ops
VM settings:
    Max. Heap Size: 1.00G
    Ergonomics Machine Class: server
    Using VM: OpenJDK 64-Bit Server VM

*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

5c02018560b3400885f29f2718cff4e3

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
```

ps: 选择安装推荐的插件可能会报错，报错信息为：`安装过程中出现一个错误： No valid crumb was included in the request`, 此时我们选择继续，然后默认下一步，接着设置Jenkins url即可。

此错误导致的原因，百度了一下。
解决方案（Solution）：

1.在apache/nginx中设置ignore_invalid_headers，或者：

2.在jenkins全局安全设置中取消勾选“防止跨站点请求伪造（Prevent Cross Site Request Forgery exploits）”。

在导出nginx-ingress的配置文件中，好像已经设置了 `ignore_invalid_headers on` 的配置。因此这里我们只需要设置取消“防止跨站点请求伪造（Prevent Cross Site Request Forgery exploits）”的勾选。

参考链接： `https://www.zhyea.com/2016/10/14/resolve-no-valid-crumb-was-included-in-the-request-error.html`

至此，Jenkins已经安装完成了。




PS: 参考链接
1. https://www.qikqiak.com/post/kubernetes-jenkins1/