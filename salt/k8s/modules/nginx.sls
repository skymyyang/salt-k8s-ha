# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Nginx Install
#******************************************
{% set nginx_version = "nginx-1.15.3" %}


include:
  - k8s.modules.base-dir
nginx-install:
  pkg.installed:
    - names:
      - gcc
      - gcc-c++
  file.managed:
    - name: /usr/local/src/{{ nginx_version }}.tar.gz
    - source: salt://k8s/files/{{ nginx_version }}/{{ nginx_version }}.tar.gz
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: cd /usr/local/src && tar -zxvf /usr/local/src/{{ nginx_version }}.tar.gz && cd /usr/local/src/{{ nginx_version }} && ./configure --with-stream --without-http --prefix=/opt/kubernetes/kube-nginx --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module && make && make install
    - unless: test -f /opt/kubernetes/kube-nginx/sbin/nginx
nginx-config:
  file.managed:
    - name: /opt/kubernetes/kube-nginx/conf/kube-nginx.conf
    - source: salt://k8s/templates/nginx/kube-nginx.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP_M1: {{ pillar['MASTER_IP_M1'] }}
        MASTER_IP_M2: {{ pillar['MASTER_IP_M2'] }}
        MASTER_IP_M3: {{ pillar['MASTER_IP_M3'] }}
nginx-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-nginx.service
    - source: salt://k8s/templates/nginx/kube-nginx.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  service.running:
    - name: kube-nginx
    - enable: True
    - watch:
      - file: nginx-config
