# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  System basic configuration
#先设置系统基础配置
#******************************************


#定义kubernetes配置文件目录
kubernetes-etc-dir:
  file.directory:
    - name: /etc/kubernetes

#定义证书存放目录
kubernetes-pki-dir:
  file.directory:
    - name: /etc/kubernetes/pki

#定义静态pod目录
kubernetes-manifests-dir:
  file.directory:
    - name: /etc/kubernetes/manifests


#关闭swap分区
swap-off:
  cmd.run:
    - name: /usr/sbin/swapoff -a && /usr/sbin/sysctl -w vm.swappiness=0 && /usr/bin/sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab


#关闭selinux以及firewalld，由于centos8使用NetworkManager来管理网络，所以不能禁用此服务
firewalld-off:
  cmd.run:
    - name: /usr/bin/systemctl stop firewalld && /usr/bin/systemctl disable firewalld


#安装依赖包
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
    - source: salt://k8s/templates/baseos/ipvs.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/bin/systemctl enable --now systemd-modules-load.service


#优化k8s系统参数
sysctl-k8s-conf:
  file.managed:
    - name: /etc/sysctl.d/k8s.conf
    - source: salt://k8s/templates/baseos/k8s.sysctl.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/sbin/sysctl --system



#修改systemctl启动的最小文件打开数量
system-k8s-conf:
  cmd.run:
    - name: /usr/bin/sed -ri 's/^#(DefaultLimitCORE)=/\1=100000/' /etc/systemd/system.conf && /usr/bin/sed -ri 's/^#(DefaultLimitNOFILE)=/\1=100000/' /etc/systemd/system.conf


#文件最大的打开数量
limits-kubernetes-conf:
  file.managed:
    - name: /etc/security/limits.d/kubernetes.conf
    - source: salt://k8s/templates/baseos/kubernetes.limits.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja