## secret 的四种形式

ConfigMap这个资源对象是Kubernetes当中非常重要的一个对象，一般情况下ConfigMap是用来存储一些非安全的配置信息，如果涉及到一些安全相关的数据的话用ConfigMap就非常不妥了，因为ConfigMap是名为存储的，我们说这个时候我们就需要用到另外一个资源对象了：Secret，Secret用来保存敏感信息，例如密码、OAuth 令牌和 ssh key等等，将这些信息放在Secret中比放在Pod的定义中或者docker镜像中来说更加安全和灵活。


- Opaque：base64 编码格式的 Secret，用来存储密码、密钥等；但数据也可以通过base64 –decode解码得到原始数据，所有加密性很弱。
- kubernetes.io/dockerconfigjson：用来存储私有docker registry的认证信息。
- kubernetes.io/service-account-token：用于被serviceaccount引用，serviceaccout 创建时Kubernetes会默认创建对应的secret。Pod如果使用了serviceaccount，对应的secret会自动挂载到Pod目录/run/secrets/kubernetes.io/serviceaccount中。
- kubernetes.io/tls: 引入外部HTTPS证书。

### Opaque Secret

Opaque 类型的数据是一个 map 类型，要求value是base64编码格式，比如我们来创建一个用户名为 admin，密码为 admin321 的 Secret 对象，首先我们先把这用户名和密码做 base64 编码。

```bash
$ echo -n "admin" | base64
YWRtaW4=
$ echo -n "admin321" | base64
YWRtaW4zMjE=
```

然后我们就可以利用上面编码过后的数据来编写一个YAML文件：(secret-demo.yaml)

```bash
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
  password: YWRtaW4zMjE=
```

然后同样的我们就可以使用kubectl命令来创建了：

```bash
$ kubectl create -f secret-demo.yaml
secret "mysecret" created
```

利用get secret命令查看：

```bash
$ kubectl get secret
NAME                  TYPE                                  DATA      AGE
default-token-n9w2d   kubernetes.io/service-account-token   3         33d
mysecret              Opaque                                2         40s
```
其中default-token-cty7pdefault-token-n9w2d为创建集群时默认创建的 secret，被serviceacount/default 引用。

我们可以输出成YAML文件进行查看：

```bash
$ kubectl get secret mysecret -o yaml
apiVersion: v1
data:
  password: YWRtaW4zMjE=
  username: YWRtaW4=
kind: Secret
metadata:
  creationTimestamp: 2018-06-19T15:27:06Z
  name: mysecret
  namespace: default
  resourceVersion: "3694084"
  selfLink: /api/v1/namespaces/default/secrets/mysecret
  uid: 39c139f5-73d5-11e8-a101-525400db4df7
type: Opaque
```

创建好Secret对象后，有两种方式来使用它：

- 以环境变量的形式
- 以Volume的形式挂载

#### 环境变量

首先我们来测试下环境变量的方式，同样的，我们来使用一个简单的busybox镜像来测试下:(secret1-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret1-pod
spec:
  containers:
  - name: secret1
    image: busybox
    command: [ "/bin/sh", "-c", "env" ]
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: username
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: password
```

主要上面环境变量中定义的secretKeyRef关键字，和configMapKeyRef是不是比较类似，一个是从Secret对象中获取，一个是从ConfigMap对象中获取，创建上面的Pod：

```bash
$ kubectl create -f secret1-pod.yaml
pod "secret1-pod" created
```

然后我们查看Pod的日志输出：

```bash
$ kubectl logs secret1-pod
...
USERNAME=admin
PASSWORD=admin321
...
```
可以看到有 USERNAME 和 PASSWORD 两个环境变量输出出来。

#### volume挂载

同样的我们用一个Pod来验证下Volume挂载，创建一个Pod文件：(secret2-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret2-pod
spec:
  containers:
  - name: secret2
    image: busybox
    command: ["/bin/sh", "-c", "ls /etc/secrets"]
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: secrets
    secret:
     secretName: mysecret
```

创建Pod:

```bash
$ kubectl create -f secret-pod2.yaml
pod "secret2-pod" created
```

然后我们查看输出日志：

```bash
$ kubectl logs secret2-pod
password
username
```

可以看到secret把两个key挂载成了两个对应的文件。当然如果想要挂载到指定的文件上面，是不是也可以使用在secretName下面添加items指定 key 和 path，这个大家可以参考ConfigMap中的方法去测试下。

### kubernetes.io/dockerconfigjson

除了上面的Opaque这种类型外，我们还可以来创建用户docker registry认证的Secret，直接使用kubectl create命令创建即可，如下：

```bash
kubectl create secret docker-registry myregistry --docker-server=harbor.mofangge.net --docker-username=admin --docker-password=admin123
```

可以使用-o yaml来输出展示出来:

```bash
$ kubectl get secret myregistry -o yaml
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJET0NLRVJfU0VSVkVSIjp7InVzZXJuYW1lIjoiRE9DS0VSX1VTRVIiLCJwYXNzd29yZCI6IkRPQ0tFUl9QQVNTV09SRCIsImVtYWlsIjoiRE9DS0VSX0VNQUlMIiwiYXV0aCI6IlJFOURTMFZTWDFWVFJWSTZSRTlEUzBWU1gxQkJVMU5YVDFKRSJ9fX0=
kind: Secret
metadata:
  creationTimestamp: 2018-06-19T16:01:05Z
  name: myregistry
  namespace: default
  resourceVersion: "3696966"
  selfLink: /api/v1/namespaces/default/secrets/myregistry
  uid: f91db707-73d9-11e8-a101-525400db4df7
type: kubernetes.io/dockerconfigjson
```

可以把上面的data.dockerconfigjson下面的数据做一个base64解码，看看里面的数据是怎样的呢？

```bash
$ echo eyJhdXRocyI6eyJET0NLRVJfU0VSVkVSIjp7InVzZXJuYW1lIjoiRE9DS0VSX1VTRVIiLCJwYXNzd29yZCI6IkRPQ0tFUl9QQVNTV09SRCIsImVtYWlsIjoiRE9DS0VSX0VNQUlMIiwiYXV0aCI6IlJFOURTMFZTWDFWVFJWSTZSRTlEUzBWU1gxQkJVMU5YVDFKRSJ9fX0= | base64 -d
{"auths":{"DOCKER_SERVER":{"username":"DOCKER_USER","password":"DOCKER_PASSWORD","email":"DOCKER_EMAIL","auth":"RE9DS0VSX1VTRVI6RE9DS0VSX1BBU1NXT1JE"}}}
```
如果我们需要拉取私有仓库中的docker镜像的话就需要使用到上面的myregistry这个Secret：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: foo
spec:
  containers:
  - name: foo
    image: 192.168.1.100:5000/test:v1
  imagePullSecrets:
  - name: myregistrykey
```

### kubernetes.io/service-account-token

另外一种Secret类型就是kubernetes.io/service-account-token，用于被serviceaccount引用。serviceaccout 创建时 Kubernetes 会默认创建对应的 secret。Pod 如果使用了 serviceaccount，对应的secret会自动挂载到Pod的/run/secrets/kubernetes.io/serviceaccount目录中。

这里我们使用一个nginx镜像来验证一下，大家想一想为什么不是呀busybox镜像来验证？当然也是可以的，但是我们就不能在command里面来验证了，因为token是需要Pod运行起来过后才会被挂载上去的，直接在command命令中去查看肯定是还没有 token 文件的。

```bash
$ kubectl run secret-pod3 --image nginx:1.7.9
deployment.apps "secret-pod3" created
$ kubectl get pods
NAME                           READY     STATUS    RESTARTS   AGE
...
secret-pod3-78c8c76db8-7zmqm   1/1       Running   0          13s
...
$ kubectl exec secret-pod3-78c8c76db8-7zmqm ls /run/secrets/kubernetes.io/serviceaccount
ca.crt
namespace
token
$ kubectl exec secret-pod3-78c8c76db8-7zmqm cat /run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImRlZmF1bHQtdG9rZW4tbjl3MmQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGVmYXVsdCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjMzY2FkOWQxLTU5MmYtMTFlOC1hMTAxLTUyNTQwMGRiNGRmNyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRlZmF1bHQifQ.0FpzPD8WO_fwnMjwpGIOphdVu4K9wUINwpXpBOJAQ-Tawd0RTbAUHcgYy3sEHSk9uvgnl1FJRQpbQN3yVR_DWSIlAtbmd4dIPxK4O7ZVdd4UnmC467cNXEBqL1sDWLfS5f03d7D1dw1ljFJ_pJw2P65Fjd13reKJvvTQnpu5U0SDcfxj675-Z3z-iOO3XSalZmkFIw2MfYMzf_WpxW0yMFCVkUZ8tBSTegA9-NJZededceA_VCOdKcUjDPrDo-CNti3wZqax5WPw95Ou8RJDMAIS5EcVym7M2_zjGiqHEL3VTvcwXbdFKxsNX-1VW6nr_KKuMGKOyx-5vgxebl71QQ
```

### kubernetes.io/tls

TLS证书，一般用在我们需要引入HTTPS证书的时候使用的。

```bash
kubectl create secret tls mofangge.cc.default --key server.key --cert server.crt
```

下面是ingress 使用TLS的yaml 文件。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: prometheus.com
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
    - secretName: mofangge.cc
      hosts:
        - prometheus.mofangge.cc
        - grafana.mofangge.cc
  rules:
    - host: prometheus.mofangge.cc
      http:
        paths:
        - backend:
            serviceName: prometheus-k8s
            servicePort: 9090
    - host: grafana.mofangge.cc
      http:
        paths:
        - backend:
            serviceName: grafana
            servicePort: 3000
```


## Secret 与 ConfigMap 对比


相同点：

- key/value的形式
- 属于某个特定的namespace
- 可以导出到环境变量
- 可以通过目录/文件形式挂载
- 通过 volume 挂载的配置信息均可热更新

不同点：
- Secret 可以被 ServerAccount 关联
- Secret 可以存储 docker register 的鉴权信息，用在 ImagePullSecret 参数中，用于拉取私有仓库的镜像
- Secret 支持 Base64 加密
- Secret 分为 kubernetes.io/service-account-token、kubernetes.io/dockerconfigjson、Opaque、kubernetes.io/tls 四种类型，而 Configmap 不区分类型
