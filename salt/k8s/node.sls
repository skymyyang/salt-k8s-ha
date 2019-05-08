# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Kubernetes Node
#******************************************

include:
  - k8s.modules.nginx
  - k8s.modules.ca-file
  - k8s.modules.cfssl
  - k8s.modules.kubectl
  - k8s.modules.kubelet
  - k8s.modules.kube-proxy
  - k8s.modules.flannel

#kubectl-csr:
#  cmd.run:
#    - name: /opt/kubernetes/bin/kubectl get csr | grep 'Pending' | awk 'NR>0{print $1}'| xargs /opt/kubernetes/bin/kubectl certificate approve
#    - onlyif: /opt/kubernetes/bin/kubectl get csr | grep 'Pending'
