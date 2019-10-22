# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  Base Env
#******************************************

#journal 日志相关目录配置
systemd-journald-log:
  file.directory:
    - name: /var/log/journal

journald-conf:
  file.directory:
    - name: /etc/systemd/journald.conf.d

kubernetes-dir:
  file.directory:
    - name: /opt/kubernetes

kubernetes-etc-dir:
  file.directory:
    - name: /etc/kubernetes
#定义高可用nginx的配置
nginx-dir:
  file.directory:
    - name: /opt/kubernetes/kube-nginx
#kubernetes二进制存放位置
kubernetes-bin:
  file.directory:
    - name: /opt/kubernetes/bin

#kubernetes相关配置文件存放
kubernetes-config:
  file.directory:
    - name: /opt/kubernetes/cfg

#用于存放生成证书的配置信息
kubernetes-ssl:
  file.directory:
    - name: /opt/kubernetes/ssl
#生成的证书会统一发放到该目录下
kubernetes-pki:
  file.directory:
    - name: /etc/kubernetes/pki

#kubernetes日志文件信息,初始化时使用systemd 的 journald 是 Centos 7 缺省的日志记录工具，该目录暂时不会使用。
kubernetes-log:
  file.directory:
    - name: /opt/kubernetes/log
#审计日志目录
kubernetes-log-audit:
  file.directory:
    - name: /var/log/kubernetes
#静态pod的配置信息。
kubernetes-staticpodpath:
  file.directory:
    - name: /etc/kubernetes/manifests
#环境变量
path-env:
  file.append:
    - name: /etc/profile
    - text:
      - export PATH=$PATH:/opt/kubernetes/bin
#安装依赖
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
#使用ipvs转发的相关模块加载
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
