# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Flannel
#******************************************
{% set flannel_version = "flannel-v0.11.0-linux-amd64" %}


kube-flannel-dir:
  file.directory:
    - name: /etc/kube-flannel

flannel-bin:
  file.managed:
    - name: /opt/kubernetes/bin/flanneld
    - source: salt://k8s/files/{{ flannel_version }}/flanneld
    - user: root
    - group: root
    - mode: 755
net-conf:
  file.managed:
    - name: /etc/kube-flannel/net-conf.json
    - source: salt://k8s/templates/flannel/net-conf.json.template
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - defaults:
        PodCIDR: {{ pillar['POD_CIDR'] }}

flannel-kubeconfig:
  file.managed:
    - name: /opt/kubernetes/bin/flannelkubeconfig.sh
    - source: salt://k8s/templates/flannel/flannelkubeconfig.sh.template
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - defaults:
        KUBE_APISERVER: {{ pillar['KUBE_APISERVER'] }}
  cmd.run:
    - name: /bin/bash /opt/kubernetes/bin/flannelkubeconfig.sh

flannel-service:
  file.managed:
    - name: /usr/lib/systemd/system/flannel.service
    - source: salt://k8s/templates/flannel/flannel.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        HOST_NAME: {{ pillar['HOST_NAME'] }}
        NODE_IP: {{ pillar['NODE_IP'] }}
        VIP_IF: {{ pillar['VIP_IF'] }}
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: flannel
    - enable: True
    - watch:
      - file: flannel-service
    - require:
      - file: net-conf
