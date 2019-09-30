# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  Kubernetes API Server
#******************************************

{% set k8s_version = "k8s-v1.15.4" %}

include:
  - k8s.modules.kubectl

#生产apiserver-kubelet-client相关证书和key
kube-api-server-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/kubernetes-csr.json
    - source: salt://k8s/templates/kube-api-server/kubernetes-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP_M1: {{ pillar['MASTER_IP_M1'] }}
        MASTER_IP_M2: {{ pillar['MASTER_IP_M2'] }}
        MASTER_IP_M3: {{ pillar['MASTER_IP_M3'] }}
        CLUSTER_KUBERNETES_SVC_IP: {{ pillar['CLUSTER_KUBERNETES_SVC_IP'] }}
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kubernetes-csr.json | /opt/kubernetes/bin/cfssljson -bare apiserver-kubelet-client
    - unless: test -f /opt/kubernetes/ssl/apiserver-kubelet-client.pem

metrics-server-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/metrics-server-csr.json
    - source: salt://k8s/templates/kube-api-server/metrics-server-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes metrics-server-csr.json | /opt/kubernetes/bin/cfssljson -bare metrics-server
    - unless: test -f /opt/kubernetes/ssl/metrics-server.pem
#将生成的秘钥拷贝到/etc/kubernetes/pki目录下
pki-key:
  cmd.run:
    - name: cp /opt/kubernetes/ssl/apiserver-kubelet-client.pem /etc/kubernetes/pki/ && cp /opt/kubernetes/ssl/apiserver-kubelet-client-key.pem /etc/kubernetes/pki/ && cp /opt/kubernetes/ssl/metrics-server.pem /etc/kubernetes/pki/front-proxy-client.pem && cp /opt/kubernetes/ssl/metrics-server-key.pem /etc/kubernetes/pki/front-proxy-client-key.pem
    - unless: test -f /etc/kubernetes/pki/front-proxy-client-key.pem
api-auth-encryption-config:
  file.managed:
    - name: /opt/kubernetes/ssl/encryption-config.yaml
    - source: salt://k8s/templates/kube-api-server/encryption-config.yaml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        ENCRYPTION_KEY: {{ pillar['ENCRYPTION_KEY'] }}
#审计策略文件
kube-apiserver-audit-yaml:
  file.managed:
    - name: /etc/kubernetes/audit-policy.yaml
    - source: salt://k8s/templates/kube-api-server/audit-policy.yml.template
    - user: root
    - group: root
    - mode: 644
kube-apiserver-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kube-apiserver
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-apiserver
    - user: root
    - group: root
    - mode: 755
    - template: jinja

kube-apiserver-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-apiserver.service
    - source: salt://k8s/templates/kube-api-server/kube-apiserver.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        NODE_IP: {{ pillar['NODE_IP'] }}
        SERVICE_CIDR: {{ pillar['SERVICE_CIDR'] }}
        NODE_PORT_RANGE: {{ pillar['NODE_PORT_RANGE'] }}
        ETCD_ENDPOINTS: {{ pillar['ETCD_ENDPOINTS'] }}
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kube-apiserver
    - enable: True
    - watch:
      - file: kube-apiserver-service
#接着在k8s-m1建立TLS bootstrap secret来提供自动签证使用
bootstrap-token-secret:
  file.managed:
    - name: /opt/kubernetes/cfg/bootstrap-token-secret.yaml
    - source: salt://k8s/templates/kube-api-server/bootstrap-token-secret.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        TOKEN_ID: {{ pillar['TOKEN_ID'] }}
        TOKEN_SECRET: {{ pillar['TOKEN_SECRET'] }}
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl delete -f /opt/kubernetes/cfg/bootstrap-token-secret.yaml;/opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/bootstrap-token-secret.yaml
#在k8s-m1建立 TLS Bootstrap Autoapprove RBAC来自动处理 CSR
kubelet-bootstrap-rbac:
  file.managed:
    - name: /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/kubelet-bootstrap-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml

#kubectl logs 来查看,但由于 API 权限,故需要建立一个 RBAC Role 来获取存取权限,这边在k8s-m1节点执行下面命令创建
apiserver-to-kubelet-rbac:
  file.managed:
    - name: /opt/kubernetes/cfg/apiserver-to-kubelet-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/apiserver-to-kubelet-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/apiserver-to-kubelet-rbac.yaml

#--authentication-kubeconfig 和 --authorization-kubeconfig 参数指定的证书需要有创建 "subjectaccessreviews" 的权限
kube-controller-manager-clusterrole:
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl create clusterrolebinding controller-manager:system:auth-delegator --user system:kube-controller-manager --clusterrole system:auth-delegator
