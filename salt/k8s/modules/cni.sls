# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  CNI For Kubernetes
#******************************************
{% set cni_version = "cni-plugins-linux-amd64-v0.8.6" %}

{# cni-dir:
  file.directory:
    - name: /etc/cni

cni-dir-net:
  file.directory:
    - name: /etc/cni/net.d
    - makedirs: True

cni-default-conf:
  file.managed:
    - name: /etc/cni/net.d/10-flannel.conflist
    - source: salt://k8s/templates/cni/10-flannel.conflist.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja #}



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
