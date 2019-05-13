# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Base Env
#******************************************

systemd-journald-log:
  file.directory:
    - name: /var/log/journal

journald-conf:
  file.directory:
    - name: /etc/systemd/journald.conf.d

kubernetes-dir:
  file.directory:
    - name: /opt/kubernetes

nginx-dir:
  file.directory:
    - name: /opt/kubernetes/kube-nginx

kubernetes-bin:
  file.directory:
    - name: /opt/kubernetes/bin

kubernetes-config:
  file.directory:
    - name: /opt/kubernetes/cfg

kubernetes-ssl:
  file.directory:
    - name: /opt/kubernetes/ssl

kubernetes-log:
  file.directory:
    - name: /opt/kubernetes/log

kubernetes-staticpodpath:
  file.directory:
    - name: /opt/kubernetes/manifests

path-env:
  file.append:
    - name: /etc/profile
    - text:
      - export PATH=$PATH:/opt/kubernetes/bin

init-pkg:
  pkg.installed:
    - names:
      - nfs-utils
      - socat
      - jq
      - psmisc
      - ipvsadm
      - ipset
      - sysstat
      - libseccomp
      - conntrack-tools
      - net-tools

ipvs-modules-set:
  file.managed:
    - name: /etc/modules-load.d/ipvs.conf
    - source: salt://k8s/templates/kube-proxy/ipvs.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/bin/systemctl enable --now systemd-modules-load.service


sysctl-k8s-conf:
  file.managed:
    - name: /etc/sysctl.d/k8s.conf
    - source: salt://k8s/templates/docker/k8s.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/sbin/sysctl --system
#设置 rsyslogd 和 systemd journald
99-prophet.conf:
  file.managed:
    - name: /etc/systemd/journald.conf.d/99-prophet.conf
    - source: salt://k8s/templates/baseos/99-prophet.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/bin/systemctl restart systemd-journald
