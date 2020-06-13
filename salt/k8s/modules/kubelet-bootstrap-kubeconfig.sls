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