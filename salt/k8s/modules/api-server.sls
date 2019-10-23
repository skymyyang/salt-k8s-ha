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
