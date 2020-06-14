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
    - k8s.worker
  'etcd-role:node':
    - match: grain
    - k8s.etcd
  'admin-role:admin':
    - match: grain
    - k8s.modules.ca-file-generate
  'k8s-role:master':
    - match: grain
    - k8s.master
  'admin-role:admin':
    - match: grain
    - k8s.modules.kubelet-bootstrap-kubeconfig
  'worker-role: node':
    - match: grain
    - k8s.node
  'calico-role:admin':
    - match: grain
    - k8s.modules.calico
