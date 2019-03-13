# ingress-controller扩展

## `daemonset`和`hostNetwork`相结合

- `Ingress`其实就是一组基于DNS名称或URL路径把请求转发至指定的`service`资源规则，用于将集群外部的请求流量转发至集群内部完成服务发布。
- `ingress-controller`本身需要通过`cluster-svc`或者`nodePort`的方式暴露在集群外部。这样就会导致服务间网络的多层转发，增加网络开销。
- 我们可以选择以`Damonset` 和 共享`node`节点宿主机网络的方式部署 `Ingress-Controller`.而不再需要部署`Ingress-Controller`的 `svc`。没有额外的网络开销，我们只需要在前端配置`nginx`转发到后端指定`node`节点的`80`或者`443`端口即可。
- 我们在部署`Damonset`时需要根据`labels`标签选择器选择指定节点即可。
- 此时也可以解决我们内部`kubernetes`集群没有LB的尴尬。

## 部署方式
- 修改详情，大家可自行参考 `/srv/addons/nginx-ingress-dm/` 下的`ingress-controller.yml` 和 `ingress-controller-svc.yml` 文件。

- 主要修改内容

```yaml
nodeSelector:
  ingress: nginx
hostNetwork: true
```
- 部署

```Bash
#先将需要部署ingress-controller节点打上labels，注意这两个节点的80和443端口不要被占用。
kubectl label nodes linux-node1 ingress=nginx
kubectl label nodes linux-node3 ingress=nginx
#先删除之前部署的ingress
kubectl delete -f /srv/addons/nginx-ingress/
#然后应用一下文件
kubectl apply -f /srv/addons/nginx-ingress-dm/
```
