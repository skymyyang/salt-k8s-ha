# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  CfSSL Tools
#******************************************
{% set cfssl_version = "1.4.1" %}
{% set k8s_version = "k8s-v1.18.2" %}


#安装cfssl工具集
cfssl-certinfo:
  file.managed:
    - name: /usr/local/bin/cfssl-certinfo
    - source: salt://k8s/files/cfssl/cfssl-certinfo_{{ cfssl_version }}_linux_amd64
    - user: root
    - group: root
    - mode: 755

cfssl-json:
  file.managed:
    - name: /usr/local/bin/cfssljson
    - source: salt://k8s/files/cfssl/cfssljson_{{ cfssl_version }}_linux_amd64
    - user: root
    - group: root
    - mode: 755

cfssl:
  file.managed:
    - name: /usr/local/bin/cfssl
    - source: salt://k8s/files/cfssl/cfssl_{{ cfssl_version }}_linux_amd64
    - user: root
    - group: root
    - mode: 755

#配置kubectl
kubectl-bin:
  file.managed:
    - name: /usr/local/bin/kubectl
    - source: salt://k8s/files/{{ k8s_version }}/bin/kubectl
    - user: root
    - group: root
    - mode: 755
#配置opensshl工具
init-pkg:
  pkg.installed:
    - names:
      - openssl
      - openssl-devel