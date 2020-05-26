# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Nginx Install
#******************************************
#nginx使用stable版本
{% set nginx_version = "nginx-1.18.0" %}


nginx-dir:
  file.directory:
    - name: /usr/local/kube-nginx
nginx-install:
  pkg.installed:
    - names:
      - gcc
      - gcc-c++
      - make
  file.managed:
    - name: /usr/local/src/{{ nginx_version }}.tar.gz
    - source: salt://k8s/files/{{ nginx_version }}/{{ nginx_version }}.tar.gz
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: cd /usr/local/src && tar -zxvf /usr/local/src/{{ nginx_version }}.tar.gz && cd /usr/local/src/{{ nginx_version }} && ./configure --with-stream --without-http --prefix=/usr/local/kube-nginx --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module && make && make install
    - unless: test -f /usr/local/kube-nginx/sbin/nginx
nginx-config:
  file.managed:
    - name: /usr/local/kube-nginx/conf/kube-nginx.conf
    - source: salt://k8s/templates/nginx/kube-nginx.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_H1: {{ pillar['MASTER_H1'] }}
        MASTER_H2: {{ pillar['MASTER_H2'] }}
        MASTER_H3: {{ pillar['MASTER_H3'] }}
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
