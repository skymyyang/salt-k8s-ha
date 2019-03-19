# Kubernetes Dashboard

## 创建Dashboard

  需要CoreDNS部署成功之后再安装Dashboard。

```bash
[root@linux-node1 ~]# kubectl create -f /srv/addons/dashboard/
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user created
secret/kubernetes-dashboard-certs created
serviceaccount/kubernetes-dashboard created
role.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
deployment.apps/kubernetes-dashboard created
service/kubernetes-dashboard created
```

## 访问Dashboard

    https://192.168.150.141:30000

用户名:admin  密码：admin 选择Token令牌模式登录。

### 获取Token

```bash
[root@linux-node1 dashboard]# kubectl get svc -n kube-system
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
coredns                ClusterIP   10.1.0.2       <none>        53/UDP,53/TCP   16h
kubernetes-dashboard   NodePort    10.1.59.125    <none>        443:30000/TCP   4m9s
metrics-server         ClusterIP   10.1.147.166   <none>        443/TCP         16h
[root@linux-node1 dashboard]# kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
Name:         admin-user-token-xqgs9
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin-user
              kubernetes.io/service-account.uid: ebc22e42-3afd-11e9-8b62-000c294df153

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1359 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLXhxZ3M5Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlYmMyMmU0Mi0zYWZkLTExZTktOGI2Mi0wMDBjMjk0ZGYxNTMiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.mIy5V1JmSFoy0CHnbk25jn3D0ajqfPaX-0WQJSzqmmXz2J9rQ-tlyrc9Sn22JkrQWqFyNaaBfbyI1tdgRgw9q8cA0kaPZCV8Q_pz7VdeLCnXoDUbpzgGm6QqdwY_42HmSkxd6GBKEZLwbPEyTTabPeml3DtvQxGEUD58TKoxUojaRUOR2DPBuwSUxPhrG8c3gN-r3p9nRtwrVdoK2DkFifFb8zcLk3uS3j4Yl_PdpEArhqdnFpg-XOg5e4-9MkIh25WOHJl0keYRenM51nUS24hLob13JvdcSTSo-IQXN6jtaAL0tL-P1RLMeMvlDRhvgSwrGOETuYmJgbVWp_7H3w

```
