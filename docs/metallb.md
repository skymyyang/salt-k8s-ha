## Kubernetes部署metallb LoadBalancer

## MetalLB介绍

- MetalLB是使用标准路由协议的裸机Kubernetes集群的负载平衡器实现。目前还处于测试阶段。
- Kubernetes没有为裸机群集提供网络负载平衡器（类型为LoadBalancer的服务）的实现。Kubernetes提供的Network LB的实现都是粘合代码，可以调用各种IaaS平台（GCP，AWS，Azure ......）。如果您未在受支持的IaaS平台（GCP，AWS，Azure ...）上运行，则LoadBalancers将在创建时无限期地保持“挂起”状态。
- MetalLB旨在通过提供与标准网络设备集成的网络LB实现来纠正这种不平衡，以便裸机集群上的外部服务也“尽可能”地工作。
- 裸机群集运营商留下了两个较小的工具来将用户流量带入其集群，“NodePort”和“externalIPs”服务。这两种选择都对生产使用产生了重大影响，这使得裸露的金属集群成为Kubernetes生态系统中的二等公民。

## MetalLB基本原理

- Metallb 会在 Kubernetes 内运行，监控服务对象的变化，一旦察觉有新的LoadBalancer 服务运行，并且没有可申请的负载均衡器之后，就会完成两部分的工作：

  1. 地址分配：用户需要在配置中提供一个地址池，Metallb 将会在其中选取地址分配给服务。
  2. 地址广播：根据不同配置，Metallb 会以二层（ARP/NDP）或者 BGP 的方式进行地址的广播。

![基本原理图](https://skymyyang.github.io/img/metallb.png)

## 部署metallb负载均衡器

- 官方部署文档：`https://metallb.universe.tf/tutorial/layer2/`
- 项目地址：`https://github.com/google/metallb`
- Metallb 支持 Helm 和 YAML 两种安装方法，这里我们使用第二种:

```Bash
$ wget https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
$ kubectl apply -f metallb.yaml
```
查看运行的pod,metalLB包含两个部分： a cluster-wide controller, and a per-machine protocol speaker

```Bash
[root@linux-node1 metallb]# kubectl get pod -n metallb-system  -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP                NODE          NOMINATED NODE   READINESS GATES
controller-7cc9c87cfb-6jl2p   1/1     Running   0          22h   10.2.86.4         linux-node2   <none>           <none>
speaker-5w26c                 1/1     Running   0          22h   192.168.150.144   linux-node4   <none>           <none>
speaker-bbf54                 1/1     Running   0          22h   192.168.150.141   linux-node1   <none>           <none>
speaker-j627k                 1/1     Running   0          22h   192.168.150.142   linux-node2   <none>           <none>
speaker-z9r7h                 1/1     Running   0          22h   192.168.150.143   linux-node3   <none>           <none>
```
目前还没有宣布任何内容，因为我们没有提供ConfigMap，也没有提供负载均衡地址的服务。
接下来我们要生成一个 Configmap 文件，为 Metallb 设置网址范围以及协议相关的选择和配置，这里以一个简单的二层配置为例:

```Bash
[root@linux-node1 metallb]# wget https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/example-layer2-config.yaml
[root@linux-node1 metallb]# cat example-layer2-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: my-ip-space
      protocol: layer2
      addresses:
      - 192.168.150.240-192.168.150.249
#这里的 IP 地址范围需要跟集群实际情况相对应;
```

执行yaml文件

```Bash
kubectl apply -f example-layer2-config.yaml
```

## 创建后端应用和服务测试

```Bash
$ wget https://raw.githubusercontent.com/google/metallb/master/manifests/tutorial-2.yaml
$ kubectl apply -f tutorial-2.yaml
```
查看yaml文件配置，包含了一个deployment和一个LoadBalancer类型的service，默认即可.

 `[root@linux-node1 metallb]# cat tutorial-2.yaml`

```YAML
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1
        ports:
        - name: http
          containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
```
查看service分配的EXTERNAL-IP

```Bash
[root@linux-node1 metallb]# kubectl get svc
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)        AGE
kubernetes      ClusterIP      10.1.0.1       <none>            443/TCP        14d
myapp-service   LoadBalancer   10.1.143.177   192.168.150.241   80:31579/TCP   21h
nginx           LoadBalancer   10.1.203.181   192.168.150.240   80:20233/TCP   22h
```
访问测试

```Bash
[root@linux-node1 metallb]# curl http://192.168.150.240
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

#### 到这里metallb loadbalancer部署完成，你可以定义kubernetes dashboard，granafa dashboard等各种应用服务，以loadbalancer的方式直接访问，不是一般的方便。只能说贼方便。
