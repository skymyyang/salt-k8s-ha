# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes Master
#******************************************

base:
  'k8s-role:master':
    - match: grain
    - k8s.master
  'k8s-role:node':
    - match: grain
    - k8s.node
  'etcd-role:node':
    - match: grain
    - k8s.etcd
