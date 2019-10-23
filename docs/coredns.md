# Kubernetes CoreDNS

## 部署集群DNS

DNS 是 k8s 集群首先需要部署的，集群中的其他 pods 使用它提供域名解析服务；主要可以解析 集群服务名 SVC 和 Pod hostname；目前 k8s v1.9+ 版本可以有两个选择：kube-dns 和 coredns（推荐），可以选择其中一个部署安装。
配置文件参考 `https://github.com/kubernetes/kubernetes` 项目目录 `kubernetes/cluster/addons/dns`

本项目暂不支持，自动化安装coredns，需要手动安装。 配置模板在 `/srv/addons/coredns/coredns.yaml`,可自行修改镜像版本以及配置。

## 创建CoreDNS
```bash
[root@linux-node1 ~]# kubectl create -f /srv/addons/coredns/coredns.yaml

[root@linux-node1 ~]# kubectl get pod -n kube-system
NAME                                    READY     STATUS    RESTARTS   AGE
coredns-77c989547b-9pj8b                1/1       Running   0          6m
coredns-77c989547b-kncd5                1/1       Running   0          6m
```
