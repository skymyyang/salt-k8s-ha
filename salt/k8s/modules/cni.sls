# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  CNI For Kubernetes
#******************************************
{% set cni_version = "cni-plugins-amd64-v0.7.4" %}

cni-dir:
  file.directory:
    - name: /etc/cni

cni-dir-net:
  file.directory:
    - name: /etc/cni/net.d

cni-default-conf:
  file.managed:
    - name: /etc/cni/net.d/10-flannel.conflist
    - source: salt://k8s/templates/cni/10-flannel.conflist.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja

cni-bin:
  file.recurse:
    - name: /opt/kubernetes/bin/cni
    - source: salt://k8s/files/{{ cni_version }}/
    - user: root
    - group: root
    - file_mode: 755
