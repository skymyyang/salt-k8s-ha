# -*- coding: utf-8 -*-
# #******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# # Description:  Kubernetes Proxy
# #******************************************

{% set k8s_version = "k8s-v1.18.2" %}


kube-proxy-workdir:
  file.directory:
    - name: /var/lib/kube-proxy

kube-proxy-csr-json:
  file.managed:
    - name: /etc/kubernetes/sslcert/kube-proxy-csr.json
    - source: salt://k8s/templates/kube-proxy/kube-proxy-csr.json.template
    - user: root
    - group: root
    - mode: 644

#拷贝kube-proxy kubeconfig配置文件
  
kube-proxy-kubeconfig:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - name: /etc/kubernetes/kube-proxy.kubeconfig
    - source: salt://k8s/files/cert/kube-proxy.kubeconfig

kube-proxy-bin:
  file.managed:
    - name: /usr/local/bin/kube-proxy
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-proxy
    - user: root
    - group: root
    - mode: 755

kube-proxy-config-yaml:
  file.managed:
    - name: /etc/kubernetes/kube-proxy.config.yaml
    - source: salt://k8s/templates/kube-proxy/kube-proxy.config.yaml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        CLUSTER_CIDR: {{ pillar['CLUSTER_CIDR'] }}


kube-proxy-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-proxy.service
    - source: salt://k8s/templates/kube-proxy/kube-proxy.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        HOST_NAME: {{ pillar['HOST_NAME'] }}
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kube-proxy
    - enable: True
    - watch:
      - file: kube-proxy-service
