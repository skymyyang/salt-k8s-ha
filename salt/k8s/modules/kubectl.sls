# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes kubectl
#******************************************

{% set k8s_version = "k8s-v1.13.5" %}

kubectl-admin-csr:
  file.managed:
    - name: /opt/kubernetes/ssl/admin-csr.json
    - source: salt://k8s/templates/kubectl/admin-csr.json.template
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes admin-csr.json | /opt/kubernetes/bin/cfssljson -bare admin
    - unless: test -f /opt/kubernetes/ssl/admin.pem

kubectl-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kubectl
    - source: salt://k8s/files/{{ k8s_version }}/bin/kubectl
    - user: root
    - group: root
    - mode: 755

kubectl-admin-cluster:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server={{ pillar['KUBE_APISERVER'] }} --kubeconfig=kubectl.kubeconfig

kubectl-admin-credentials:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-credentials admin --client-certificate=/opt/kubernetes/ssl/admin.pem --embed-certs=true --client-key=/opt/kubernetes/ssl/admin-key.pem --kubeconfig=kubectl.kubeconfig

kubectl-admin-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=kubectl.kubeconfig

kubectl-admin-use:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig && mkdir -p ~/.kube && /bin/cp /opt/kubernetes/cfg/kubectl.kubeconfig ~/.kube/config
