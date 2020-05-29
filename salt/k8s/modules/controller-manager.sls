# -*- coding: utf-8 -*-
#********************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Kubernetes Controller Manager
#********************************************
{% set k8s_version = "k8s-v1.18.2" %}






#拷贝二进制文件
kube-controller-manager-bin:
  file.managed:
    - name: /usr/local/bin/kube-controller-manager
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-controller-manager
    - user: root
    - group: root
    - mode: 755

#拷贝kubeconfig文件
kube-controller-manager-kubeconfig:
  file.managed:
    - name: /etc/kubernetes/controller-manager.conf
    - source: salt://k8s/files/cert/controller-manager.conf
    - user: root
    - group: root
    - mode: 644


kube-controller-manager-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-controller-manager.service
    - source: salt://k8s/templates/kube-controller-manager/kube-controller-manager.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        SERVICE_CIDR: {{ pillar['SERVICE_CIDR'] }}
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kube-controller-manager
    - enable: True
    - watch:
      - file: kube-controller-manager-service
