# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes Scheduler
#******************************************

{% set k8s_version = "k8s-v1.18.2" %}



kube-scheduler-bin:
  file.managed:
    - name: /usr/local/bin/kube-scheduler
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-scheduler
    - user: root
    - group: root
    - mode: 755


#拷贝kube-scheduler的kubeconfig文件
kube-scheduler-kubeconfig:
  file.managed:
    - name: /etc/kubernetes/scheduler.conf
    - source: salt://k8s/files/cert/scheduler.conf
    - user: root
    - group: root
    - mode: 755

kube-scheduler-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-scheduler.service
    - source: salt://k8s/templates/kube-scheduler/kube-scheduler.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: systemctl daemon-reload
    - watch:
      - file: kube-scheduler-service
  service.running:
    - name: kube-scheduler
    - enable: True
    - watch:
      - file: kube-scheduler-service
