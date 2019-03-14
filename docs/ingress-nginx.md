## 关于Service(资源)

- Service-四层调度
  - 工作模型： Userspace Iptables Ipvs三种
  - 五种类型
   1. ClusterIP 只能在集群内部可达，可以被pod和node所访问。无法接入集群外部的流量。
   2. Nodeport

   ```
   访问流程
    Client --> NodeIP:NodePort--> ClusterIP:SvcPort-->PodIP:containerPort
    一般情况会给NodePort进行负载均衡器。
   ```
   3. LoadBalancer
   4. ExternelName
   5. No ClusterIP - Headless Service(无头服务)  `ServiceName-->PodIP`


## 关于Ingress Controller和Ingress

- Ingress Controller通常是有用7层协议代理能力的控制器，自身也是运行与集群中的Pod资源对象。
  - Nginx
  - Traefik
  - Envoy

- Ingress也是标准的kubernetes资源类型之一，它其实就是一组基于DNS名称或URL路径把请求转发至指定的service资源规则，用于将集群外部的请求流量转发至集群内部完成服务发布。

- Ingress 是 Kubernetes 中的一个抽象资源,其功能是通过 Web Server 的 Virtual Host 概念以域名(Domain Name)方式转发到內部 Service,这避免了使用 Service 中的 NodePort 与 LoadBalancer 类型所带來的限制(如 Port 数量上限),而实现 Ingress 功能则是通过 Ingress Controller 来达成,它会负责监听 Kubernetes API 中的 Ingress 与 Service 资源物件,并在发生资源变化时,根据资源预期的结果来设置 Web Server

- Ingress Controller实现的基本逻辑如下：

1. 监听apiserver，获取全部ingress的定义
2. 基于ingress的定义，生成Nginx所需的配置文件(/etc/nginx/nginx.conf)
3. 执行nginx -s reload命令,重新加载nginx.conf配置文件的内容

![基本原理图](https://skymyyang.github.io/img/ingress.png)
## 部署

```bash
kubectl create ns ingress-nginx
#这里注意，要修改一下ingress-controller-svc.yml 中的externalIPs的地址。 就是你自定义LB的地址。
kubectl apply -f /srv/addons/nginx-ingress/
```

## 验证

```bash
[root@linux-node1 nginx-ingress]# kubectl -n ingress-nginx get po,svc
NAME                                            READY   STATUS    RESTARTS   AGE
pod/default-http-backend-774686c976-t6c2c       1/1     Running   0          16h
pod/nginx-ingress-controller-5784c99d57-nb7qr   1/1     Running   0          16h

NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                      AGE
service/default-http-backend   ClusterIP      10.1.121.129   <none>            80/TCP                       16h
service/ingress-nginx          LoadBalancer   10.1.159.223   192.168.150.252   80:36780/TCP,443:27505/TCP   16h

[root@linux-node1 nginx-ingress]# curl http://192.168.150.252
default backend - 404

#确认上面步骤都沒问题后,就可以通过 kubeclt 建立简单 Myapp 来测试功能
[root@linux-node1 apps]# kubectl apply -f /srv/apps/myapp-http-svc.yaml
pod/myapp unchanged
service/myapp-service unchanged
ingress.extensions/myapp unchanged
#访问测试
[root@linux-node1 apps]# curl http://192.168.150.252 -H 'Host: myapp.k8s.local'
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
```
