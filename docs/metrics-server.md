# Kubernetes metrics-server

Metrics Server 是实现了 Metrics API 的元件,其目标是取代 Heapster 作为 Pod 与 Node 提供资源的 Usage metrics,该元件会从每个 Kubernetes 节点上的 Kubelet 所公开的 Summary API 中收集 Metrics。
- Horizontal Pod Autoscaler（HPA）控制器用于实现基于CPU使用率进行自动Pod伸缩的功能
- HPA控制器基于Master的kube-controller-manager服务启动参数–horizontal-pod-autoscaler-sync-period定义是时长（默认30秒）,周期性监控目标Pod的CPU使用率,并在满足条件时对ReplicationController或Deployment中的Pod副本数进行调整,以符合用户定义的平均Pod CPU使用率。
- 在新版本的kubernetes中 Pod CPU使用率不在来源于heapster,而是来自于metrics-server。
- yml 文件来自于github https://github.com/kubernetes-incubator/metrics-server/tree/master/deploy/1.8+
- /etc/kubernetes/pki/ca.pem 文件来自于部署kubernetes集群
- 需要对yml文件进行修改才可使用 改动自行见文件。
- API相关的配置参数如下：

```bash
 --requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --requestheader-allowed-names= \
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --proxy-client-cert-file=/opt/kubernetes/ssl/metrics-server.pem \
  --proxy-client-key-file=/opt/kubernetes/ssl/metrics-server-key.pem \
```

## 创建metrics-server

```bash
[root@linux-node1 ~]# kubectl apply -f /srv/addons/metrics-server/metrics-server-1.12up.yaml
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
serviceaccount/metrics-server created
deployment.extensions/metrics-server created
service/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
```

## 查看pod状态

```bash
[root@linux-node1 ~]# kubectl -n kube-system get po -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-79b544fd7b-tkh8m   1/1     Running   0          14h
```

## 收集 Metrics,执行 kubectl top 指令查看

```bash
[root@linux-node1 ~]# kubectl get --raw /apis/metrics.k8s.io/v1beta1
{"kind":"APIResourceList","apiVersion":"v1","groupVersion":"metrics.k8s.io/v1beta1","resources":[{"name":"nodes","singularName":"","namespaced":false,"kind":"NodeMetrics","verbs":["get","list"]},{"name":"pods","singularName":"","namespaced":true,"kind":"PodMetrics","verbs":["get","list"]}]}


[root@linux-node1 ~]# kubectl get apiservice|grep metrics
v1beta1.metrics.k8s.io                  kube-system/metrics-server   True        14h

[root@linux-node1 ~]# kubectl top node
NAME          CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
linux-node1   128m         6%     884Mi           47%       
linux-node2   133m         6%     1032Mi          55%       
linux-node3   184m         9%     983Mi           52%       
linux-node4   29m          2%     343Mi           39%
```
