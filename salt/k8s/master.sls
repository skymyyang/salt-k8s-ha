# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes Master
#******************************************
include:
  - k8s.modules.nginx
  - k8s.modules.ca-file
  - k8s.modules.cfssl
  - k8s.modules.api-server
  - k8s.modules.controller-manager
  - k8s.modules.scheduler
  - k8s.modules.kubelet
  - k8s.modules.kube-proxy
  - k8s.modules.flannel
