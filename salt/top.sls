# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
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
  'admin-role:master':
    - match: grain
    - k8s.admin
