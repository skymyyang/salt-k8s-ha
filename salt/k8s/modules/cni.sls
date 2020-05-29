# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  CNI For Kubernetes
#******************************************
{% set cni_version = "cni-plugins-linux-amd64-v0.8.6" %}

cni-dir-net:
  file.directory:
    - name: /etc/cni/net.d
    - makedirs: True


cni-bin-dir:
  file.directory:
    - name: /opt/cni/bin
    - makedirs: True


cni-bin:
  file.recurse:
    - name: /opt/cni/bin
    - source: salt://k8s/files/{{ cni_version }}/
    - user: root
    - group: root
    - file_mode: 755
