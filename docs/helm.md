1.部署Helm客户端

```Bash
[root@linux-node1 ~]# cd /usr/local/src
[root@linux-node1 src]# wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz
[root@linux-node1 src]# tar zxf helm-v2.12.3-linux-amd64.tar.gz
[root@linux-node1 src]# mv linux-amd64/helm /usr/local/bin/
```

2.初始化Helm并部署Tiller服务端

```Bash
[root@linux-node1 ~]# helm init --upgrade –i \
registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.12.3 \
--stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```

3.所有节点安装socat命令

```Bash
[root@linux-node1 ~]# yum install -y socat
```

4.验证安装是否成功

```Bash
[root@linux-node1 ~]# helm version
Client: &version.Version{SemVer:"v2.12.3", GitCommit:"eecf22f77df5f65c823aacd2dbd30ae6c65f186e", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.12.3", GitCommit:"eecf22f77df5f65c823aacd2dbd30ae6c65f186e", GitTreeState:"clean"}
```

5.查看helm tiller的服务

```Bash
[root@linux-node1 ~]# kubectl get pod --all-namespaces|grep tiller
kube-system     tiller-deploy-5687f55748-qb5kg              1/1     Running   0          30s
```

6.使用Helm部署第一个应用

6.1创建服务账号

```Bash
[root@linux-node1 ~]# kubectl create serviceaccount --namespace kube-system tiller
serviceaccount "tiller" created
```

6.2.创建集群的角色绑定

```Bash
[root@linux-node1 ~]# kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
clusterrolebinding.rbac.authorization.k8s.io "tiller-cluster-rule" created
```

 6.3.为应用程序设置serviceAccount

 ```Bash
[root@linux-node1 ~]# kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
deployment.extensions "tiller-deploy" patched
```

6.4.搜索Helm应用

```Bash
[root@linux-node1 ~]# helm search jenkins
NAME          	CHART VERSION	APP VERSION	DESCRIPTION                                       
stable/jenkins	0.13.5       	2.73       	Open source continuous integration server. It s...


[root@linux-node1 ~]# helm repo list
NAME  	URL                                                   
stable	https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
local 	http://127.0.0.1:8879/charts   

[root@linux-node1 ~]# helm install stable/jenkins
```
