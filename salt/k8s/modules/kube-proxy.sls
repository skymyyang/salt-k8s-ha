# -*- coding: utf-8 -*-
# #******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: https://iokubernetes.github.io
# # Description:  Kubernetes Proxy
# #******************************************

{% set k8s_version = "k8s-v1.15.4" %}

include:
  - k8s.modules.cni
  - k8s.modules.base-dir

kube-proxy-workdir:
  file.directory:
    - name: /var/lib/kube-proxy

kube-proxy-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/kube-proxy-csr.json
    - source: salt://k8s/templates/kube-proxy/kube-proxy-csr.json.template
    - user: root
    - group: root
    - mode: 644

kube-proxy-pem:
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes  kube-proxy-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-proxy
    - unless: test -f /opt/kubernetes/ssl/kube-proxy.pem

kubeproxy-set-cluster:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server={{ pillar['KUBE_APISERVER'] }}  --kubeconfig=kube-proxy.kubeconfig

kubeproxy-set-credentials:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-credentials kube-proxy --client-certificate=/opt/kubernetes/ssl/kube-proxy.pem --client-key=/opt/kubernetes/ssl/kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig

kubeproxy-set-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig

kubeproxy-use-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig && cp /opt/kubernetes/cfg/kube-proxy.kubeconfig /etc/kubernetes/kube-proxy.kubeconfig

kube-proxy-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kube-proxy
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
