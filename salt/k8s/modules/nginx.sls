# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Nginx Install
#******************************************

include:
  - k8s.modules.base-dir
nginx-install:
  pkg.installed:
    - names:
      - nginx
nginx-config:
  file.managed:
    - name: /etc/nginx/nginx.conf
    - source: salt://k8s/templates/nginx/nginx.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP_M1: {{ pillar['MASTER_IP_M1'] }}
        MASTER_IP_M2: {{ pillar['MASTER_IP_M2'] }}
        MASTER_IP_M3: {{ pillar['MASTER_IP_M3'] }}
nginx-service:
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: nginx
    - enable: True
    - watch:
      - file: nginx-config
