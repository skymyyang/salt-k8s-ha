# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  Kubernetes kubectl
#******************************************

{% set k8s_version = "k8s-v1.15.4" %}




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
