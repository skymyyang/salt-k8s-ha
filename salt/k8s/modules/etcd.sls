# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: skymyyyang.github.io
# Description:  ETCD Cluster
#******************************************
{% set etcd_version = "etcd-v3.3.13-linux-amd64" %}

include:
  - k8s.modules.base-dir

etcd-bin:
  file.managed:
    - name: /opt/kubernetes/bin/etcd
    - source: salt://k8s/files/{{ etcd_version }}/etcd
    - user: root
    - group: root
    - mode: 755

etcdctl-bin:
 file.managed:
   - name: /opt/kubernetes/bin/etcdctl
   - source: salt://k8s/files/{{ etcd_version }}/etcdctl
   - user: root
   - group: root
   - mode: 755

etcd-dir:
  file.directory:
    - name: /var/lib/etcd
etcd-wal-dir:
  file.directory:
    - name: /var/lib/etcd/wal
etcd-config-dir:
  file.directory:
    - name: /etc/etcd

etcd-config:
  file.managed:
    - name: /etc/etcd/etcd.config.yml
    - source: salt://k8s/templates/etcd/etcd.confing.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        NODE_IP: {{ grains['fqdn_ip4'][0] }}
        ETCD_NAME: {{ grains['etcd-name'] }}
        ETCD_CLUSTER: {{ pillar['ETCD_CLUSTER'] }}

etcd-service:
  file.managed:
    - name: /usr/lib/systemd/system/etcd.service
    - source: salt://k8s/templates/etcd/etcd.service.template
    - user: root
    - group: root
    - mode: 644
    - watch:
      - file: etcd-config
  cmd.run:
    - name: systemctl daemon-reload
    - watch:
      - file: etcd-service
  service.running:
    - name: etcd
    - enable: True
    - watch:
      - file: etcd-service
