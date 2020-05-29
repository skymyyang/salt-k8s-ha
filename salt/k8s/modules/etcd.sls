# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  ETCD Cluster
#******************************************
{% set etcd_version = "etcd-v3.4.8-linux-amd64" %}



etcd-bin:
  file.managed:
    - name: /usr/local/bin/etcd
    - source: salt://k8s/files/{{ etcd_version }}/etcd
    - user: root
    - group: root
    - mode: 755

etcdctl-bin:
 file.managed:
   - name: /usr/local/bin/etcdctl
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


etcd-service:
  file.managed:
    - name: /usr/lib/systemd/system/etcd.service
    - source: salt://k8s/templates/etcd/etcd.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        NODE_IP: {{ grains['fqdn_ip4'][0] }}
        ETCD_NAME: {{ grains['etcd-name'] }}
        ETCD_CLUSTER: {{ pillar['ETCD_CLUSTER'] }}
  cmd.run:
    - name: systemctl daemon-reload
    - watch:
      - file: etcd-service
  service.running:
    - name: etcd
    - enable: True
    - watch:
      - file: etcd-service
