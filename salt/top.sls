# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes Master
#******************************************

base:
  'worker-role: node':
    - match: grain
    - k8s.baseset
  'etcd-role:node':
    - match: grain
    - k8s.etcd
  'ca-file-role: admin':
    - match: grain
    - k8s.modules.ca-file-generate
  'k8s-role:master':
    - match: grain
    - k8s.master
  'kubelet-bootstrap-role: admin':
    - match: grain
    - k8s.modules.kubelet-bootstrap-kubeconfig
  'kubelet-role: node':
    - match: grain
    - k8s.node
  'calico-role:admin':
    - match: grain
    - k8s.modules.calico
