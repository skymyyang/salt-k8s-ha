# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes Master
#******************************************

base:
'etcd-role:node':
    - match: grain
    - k8s.etcd
  'admin-role:admin':
    - match: grain
    - k8s.modules.ca-file-generate
    - k8s.modules.kubelet-bootstrap
  'k8s-role:master':
    - match: grain
    - k8s.master
  'k8s-role:node':
    - match: grain
    - k8s.node
  'sa-role:admin':
    - match: grain
    - k8s.admin
  'calico-role:admin':
    - match: grain
    - k8s.modules.calico
