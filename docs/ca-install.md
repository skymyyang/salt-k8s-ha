# 手动制作CA证书

## 1.安装 CFSSL
```
[root@linux-node1 ~]# cd /usr/local/src
[root@linux-node1 src]# wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
[root@linux-node1 src]# wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
[root@linux-node1 src]# wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
[root@linux-node1 src]# chmod +x cfssl*
[root@linux-node1 src]# mv cfssl-certinfo_linux-amd64 /opt/kubernetes/bin/cfssl-certinfo
[root@linux-node1 src]# mv cfssljson_linux-amd64  /opt/kubernetes/bin/cfssljson
[root@linux-node1 src]# mv cfssl_linux-amd64  /opt/kubernetes/bin/cfssl
复制cfssl命令文件到k8s-node1和k8s-node2节点。如果实际中多个节点，就都需要同步复制。
[root@linux-node1 ~]# scp /opt/kubernetes/bin/cfssl* linux-node2: /opt/kubernetes/bin
[root@linux-node1 ~]# scp /opt/kubernetes/bin/cfssl* linux-node3: /opt/kubernetes/bin
[root@linux-node1 ~]# scp /opt/kubernetes/bin/cfssl* linux-node4: /opt/kubernetes/bin
```

## 2.初始化cfssl
```
[root@linux-node1 src]# mkdir ssl && cd ssl
[root@linux-node1 ssl]# cfssl print-defaults config > config.json
[root@linux-node1 ssl]# cfssl print-defaults csr > csr.json
```

## 3.创建用来生成 CA 文件的 JSON 配置文件

CA 配置文件用于配置根证书的使用场景 (profile) 和具体参数 (usage，过期时间、服务端认证、客户端认证、加密等)

```bash
[root@linux-node1 ssl]# vim ca-config.json
{
  "signing": {
    "default": {
      "expiry": "876000h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
```
- signing：表示该证书可用于签名其它证书（生成的 ca.pem 证书中 CA=TRUE）；
- server auth：表示 client 可以用该该证书对 server 提供的证书进行验证；
- client auth：表示 server 可以用该该证书对 client 提供的证书进行验证；
- "expiry": "876000h"：证书有效期设置为 100 年；

## 4.创建用来生成 CA 证书签名请求（CSR）的 JSON 配置文件
```bash
[root@linux-node1 ssl]# vim ca-csr.json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]，
  "ca": {
    "expiry": "876000h"
 }
}
```
- CN：Common Name：kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)，浏览器使用该字段验证网站是否合法；
- O：Organization：kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)；
- kube-apiserver 将提取的 User、Group 作为 RBAC 授权的用户标识；

PS:
- 不同证书 csr 文件的 CN、C、ST、L、O、OU 组合必须不同，否则可能出现 `PEER'S CERTIFICATE HAS AN INVALID SIGNATURE` 错误；
- 后续创建证书的 csr 文件时，CN 都不相同（C、ST、L、O、OU 相同），以达到区分的目的
## 5.生成CA证书（ca.pem）和密钥（ca-key.pem）
```
[root@ linux-node1 ssl]# cfssl gencert -initca ca-csr.json | cfssljson -bare ca
[root@ linux-node1 ssl]# ls -l ca*
-rw-r--r-- 1 root root  290 Mar  4 13:45 ca-config.json
-rw-r--r-- 1 root root 1001 Mar  4 14:09 ca.csr
-rw-r--r-- 1 root root  208 Mar  4 13:51 ca-csr.json
-rw------- 1 root root 1679 Mar  4 14:09 ca-key.pem
-rw-r--r-- 1 root root 1359 Mar  4 14:09 ca.pem
```
这是Kubernetes 集群根证书CA(Kubernetes集群组件的证书签发机构)；对应kubeadm安装生成证书的路径为：

```
/etc/kubernetes/pki/ca.pem  ------>  /etc/kubernetes/pki/ca.crt 
/etc/kubernetes/pki/ca-key.pem  ------> /etc/kubernetes/pki/ca.key
```

## 6.分发证书
```
# cp ca.csr ca.pem ca-key.pem ca-config.json /opt/kubernetes/ssl
SCP证书到linux-node2和linux-node3节点
# scp ca.csr ca.pem ca-key.pem ca-config.json linux-node2:/opt/kubernetes/ssl
# scp ca.csr ca.pem ca-key.pem ca-config.json linux-node3:/opt/kubernetes/ssl
# scp ca.csr ca.pem ca-key.pem ca-config.json linux-node4:/opt/kubernetes/ssl
```
