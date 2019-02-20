# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  Haproxy Install
#******************************************

include:
  - k8s.modules.base-dir
haproxy-install:
  pkg.installed:
    - names:
      - haproxy
haproxy-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://k8s/templates/haproxy/haproxy.cfg.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP_M1: {{ pillar['MASTER_IP_M1'] }}
        MASTER_IP_M2: {{ pillar['MASTER_IP_M2'] }}
        MASTER_IP_M3: {{ pillar['MASTER_IP_M3'] }}
haproxy-service:
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: haproxy
    - enable: True
    - watch:
      - file: haproxy-config
