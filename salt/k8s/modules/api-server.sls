# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes API Server
#******************************************

{% set k8s_version = "k8s-v1.18.2" %}

#定义审计日志目录
audit-log-dir:
  file.directory:
    - name: /var/log/kubernetes
#定义加密配置文件
api-auth-encryption-config:
  file.managed:
    - name: /etc/kubernetes/pki/encryption-config.yaml
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

#拷贝CA证书
ca-pem-key-pki:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - names:
      - /etc/kubernetes/pki/ca.pem
        - source: salt://k8s/files/cert/ca.pem
      - /etc/kubernetes/pki/ca-key.pem
        - source: salt://k8s/files/cert/ca-key.pem

#拷贝apiserver-kubelet-client证书
kube-apiserver-cert:
    file.managed:
    - user: root
    - group: root
    - mode: 644
    - names:
      - /etc/kubernetes/pki/apiserver-kubelet-client.pem
        - source: salt://k8s/files/cert/apiserver-kubelet-client.pem
      - /etc/kubernetes/pki/apiserver-kubelet-client-key.pem
        - source: salt://k8s/files/cert/apiserver-kubelet-client-key.pem
#拷贝metrics所使用的证书
kubenetes-metrics-cert:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - names:
      - /etc/kubernetes/pki/front-proxy-client.pem
        - source: salt://k8s/files/cert/front-proxy-client.pem
      - /srv/salt/k8s/files/cert/front-proxy-client-key.pem
        - source: salt://k8s/files/cert/front-proxy-client-key.pem


#拷贝kube-apiserver二进制文件
kube-apiserver-bin:
  file.managed:
    - name: /usr/local/bin/kube-apiserver
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
