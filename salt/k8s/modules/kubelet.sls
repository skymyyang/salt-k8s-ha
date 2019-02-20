# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes Node kubelet
#******************************************

{% set k8s_version = "k8s-v1.12.5" %}


include:
  - k8s.modules.cni
  - k8s.modules.base-dir
  - k8s.modules.docker

kubelet-workdir:
  file.directory:
    - name: /var/lib/kubelet
#创建 kubelet bootstrap kubeconfig 文件
kubeconfig-set-cluster:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server=https://{{ pillar['MASTER_VIP'] }}:8443 --kubeconfig=kubelet-bootstrap.kubeconfig

kubeconfig-set-credentials:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-credentials tls-bootstrap-token-user --token={{ pillar['BOOTSTRAP_TOKEN'] }} --kubeconfig=kubelet-bootstrap.kubeconfig

kubeconfig-set-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-context tls-bootstrap-token-user@kubernetes --cluster=kubernetes --user=tls-bootstrap-token-user --kubeconfig=kubelet-bootstrap.kubeconfig

kubeconfig-use-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config use-context tls-bootstrap-token-user@kubernetes --kubeconfig=kubelet-bootstrap.kubeconfig

kubelet-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kubelet
    - source: salt://k8s/files/{{ k8s_version }}/bin/kubelet
    - user: root
    - group: root
    - mode: 755
kubelet-config-yaml:
  file.managed:
    - name: /opt/kubernetes/cfg/kubelet-conf.yaml
    - source: salt://k8s/templates/kubelet/kubelet-conf.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        CLUSTER_DNS_SVC_IP: {{ pillar['CLUSTER_DNS_SVC_IP'] }}
        CLUSTER_DNS_DOMAIN: {{ pillar['CLUSTER_DNS_DOMAIN'] }}
kubelet-service:
  file.managed:
    - name: /usr/lib/systemd/system/kubelet.service
    - source: salt://k8s/templates/kubelet/kubelet.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    {% if grains['fqdn'] == pillar['MASTER_H1']  %}
    - ROLES: "master"
    {% elif grains['fqdn'] == pillar['MASTER_H2'] %}
    - ROLES: "master"
    {% elif grains['fqdn'] == pillar['MASTER_H3'] %}
    - ROLES: "master"
    {% else %}
    - ROLES: "node"
    {% endif %}
    - defaults:
        HOST_NAME: {{ pillar['HOST_NAME'] }}
        
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kubelet
    - enable: True
    - watch:
      - file: kubelet-service
