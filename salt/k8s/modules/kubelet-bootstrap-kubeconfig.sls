#创建 kubelet bootstrap kubeconfig 文件
#向 kubeconfig 写入的是 token，bootstrap 结束后 kube-controller-manager 为 kubelet 创建 client 和 server 证书；
#由于此证书与需要创建tocker，需要再api-server是可通信的情况下生成。因此再master的admin节点中进行操作

kubelet-bootstrap-kubeconfig:
  file.managed:
    - name: /etc/kubernetes/sslcert/tls-bootstrap-secret-kubeconfig.sh
    - source: salt://k8s/templates/ca/tls-bootstrap-secret-kubeconfig.sh.template
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - defaults:
        KUBE_APISERVER: {{ pillar["KUBE_APISERVER"] }}
        TOKEN_ID: {{ pillar["TOKEN_ID"] }}
        TOKEN_SECRET: {{ pillar["TOKEN_SECRET"] }}
        BOOTSTRAP_TOKEN: {{ pillar["BOOTSTRAP_TOKEN"] }}
  cmd.run:
    - name: /bin/bash /etc/kubernetes/sslcert/tls-bootstrap-secret-kubeconfig.sh
    - unless: test -f /etc/kubernetes/sslcert/bootstrap.kubeconfig

kubelet-bootstrap-kubeconfig-cp:
  file.copy:
    - user: root
    - group: root
    - mode: 644
    - name: /srv/salt/k8s/files/cert/bootstrap-kubelet.conf
    - source: /etc/kubernetes/sslcert/bootstrap.kubeconfig
    - force: True


#在k8s-m1建立 TLS Bootstrap Autoapprove RBAC来自动处理 CSR
kubelet-bootstrap-rbac:
  file.managed:
    - name: /etc/kubernetes/csr-crb.yaml
    - source: salt://k8s/templates/kube-api-server/csr-crb.yaml
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/local/bin/kubectl create -f /etc/kubernetes/csr-crb.yaml

#授予 kube-apiserver 访问 kubelet API 的权限
#在执行 kubectl exec、run、logs 等命令时，apiserver 会将请求转发到 kubelet 的 https 端口。
#这里定义 RBAC 规则，授权 apiserver 使用的证书（kubernetes.pem）
#用户名（CN：kuberntes）访问 kubelet API 的权限
apiserver-to-kubelet-rbac:
  file.managed:
    - name: /etc/kubernetes/apiserver-to-kubelet-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/apiserver-to-kubelet-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/local/bin/kubectl create -f /etc/kubernetes/apiserver-to-kubelet-rbac.yaml

#--authentication-kubeconfig 和 --authorization-kubeconfig 参数指定的证书需要有创建 "subjectaccessreviews" 的权限
# kube-controller-manager-clusterrole:
# cmd.run:
#    - name: /opt/kubernetes/bin/kubectl create clusterrolebinding controller-manager:system:auth-delegator --user system:kube-controller-manager --clusterrole system:auth-delegator #}