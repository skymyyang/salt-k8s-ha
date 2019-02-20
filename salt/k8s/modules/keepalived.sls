# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyang.github.io
# Description:  Keepalived Install
#******************************************

include:
  - k8s.modules.base-dir
keepalived-install:
  pkg.installed:
    - names:
      - keepalived
keepalived-config:
  cmd.run:
    - name: rm -rf /etc/keepalived/keepalived.conf
  file.managed:
    - name: /etc/keepalived/keepalived.conf
    - source: salt://k8s/templates/keepalived/keepalived.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - VIP_IF: {{ pillar['VIP_IF'] }}
    - MASTER_VIP: {{ pillar['MASTER_VIP'] }}
    {% if grains['fqdn'] == pillar['MASTER_H1'] %}
    - ROUTEID: "lb-master-135"
    - STATEID: "MASTER"
    - PRIORITYID: "150"
    {% elif grains['fqdn'] == pillar['MASTER_H2'] %}
    - ROUTEID: "lb-backup-136"
    - STATEID: "BACKUP"
    - PRIORITYID: "120"
    {% elif grains['fqdn'] == pillar['MASTER_H3'] %}
    - ROUTEID: "lb-backup-137"
    - STATEID: "BACKUP"
    - PRIORITYID: "100"
    {% endif %}

keepalived-service:
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: keepalived
    - enable: True
    - watch:
      - file: keepalived-config
