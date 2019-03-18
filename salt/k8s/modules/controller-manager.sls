# -*- coding: utf-8 -*-
#********************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes Controller Manager
#********************************************
{% set k8s_version = "k8s-v1.13.4" %}





kube-controller-manager-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/kube-controller-manager-csr.json
    - source: salt://k8s/templates/kube-controller-manager/kube-controller-manager-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP_M1: {{ pillar['MASTER_IP_M1'] }}
        MASTER_IP_M2: {{ pillar['MASTER_IP_M2'] }}
        MASTER_IP_M3: {{ pillar['MASTER_IP_M3'] }}
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kube-controller-manager-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-controller-manager
    - unless: test -f /opt/kubernetes/ssl/kube-controller-manager.pem

kube-controller-manager-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kube-controller-manager
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-controller-manager
    - user: root
    - group: root
    - mode: 755

kube-controller-manager-cluster:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server={{ pillar['KUBE_APISERVER'] }} --kubeconfig=kube-controller-manager.kubeconfig

kubectl-controller-manager-credentials:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-credentials system:kube-controller-manager --client-certificate=/opt/kubernetes/ssl/kube-controller-manager.pem --embed-certs=true --client-key=/opt/kubernetes/ssl/kube-controller-manager-key.pem --kubeconfig=kube-controller-manager.kubeconfig

kubectl-controller-manager-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig

kubectl-controller-manager-use:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig


kube-controller-manager-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-controller-manager.service
    - source: salt://k8s/templates/kube-controller-manager/kube-controller-manager.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        SERVICE_CIDR: {{ pillar['SERVICE_CIDR'] }}
        POD_CIDR: {{ pillar['POD_CIDR'] }}
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kube-controller-manager
    - enable: True
    - watch:
      - file: kube-controller-manager-service
