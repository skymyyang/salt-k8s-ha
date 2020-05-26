# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes Master
#******************************************
include:
  - k8s.modules.baseos
  - k8s.modules.nginx
  - k8s.modules.api-server
  - k8s.modules.controller-manager
  - k8s.modules.scheduler
  - k8s.modules.kubelet
  - k8s.modules.kube-proxy
