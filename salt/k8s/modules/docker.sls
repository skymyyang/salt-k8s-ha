# -*- coding: utf-8 -*-
#******************************************
# Author:       skymyyang
# Email:        yang-li@live.cn
# Organization: https://www.cnblogs.com/skymyyang/
# Description:  Docker Install
#******************************************


#安装docker
docker-install:
  cmd.run:
    - name: yum install -y yum-utils device-mapper-persistent-data lvm2 && yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo && yum install -y https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/edge/Packages/containerd.io-1.2.13-3.1.el7.x86_64.rpm 
  pkg.installed:
    - name: docker-ce
    - version: 3:19.03.9-3.el7
    - allow_updates: True

#创建docker配置文件目录
docker-config-dir:
  file.directory:
    - name: /etc/docker


#docker命令补全
docker-bash-completion:
  pkg.installed:
    - name: bash-completion
  cmd.run:
    - name: /bin/cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/

#配置文件创建
docker-daemon-config:
  file.managed:
    - name: /etc/docker/daemon.json
    - source: salt://k8s/templates/docker/daemon.json.template
    - user: root
    - group: root
    - mode: 644

#定义服务启动
systemctl-docker-service.d:
  file.directory:
    - name: /etc/systemd/system/docker.service.d
#防止FORWARD的DROP策略影响转发,给docker daemon添加下列参数修正，当然暴力点也可以iptables -P FORWARD ACCEPT，具体参数查看10-docker.conf配置文件
docker-service:
  file.managed:
     - name: /etc/systemd/system/docker.service.d/10-docker.conf
     - source: salt://k8s/templates/docker/10-docker.conf.template
     - user: root
     - group: root
     - mode: 755
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: docker
    - enable: True
    - watch:
      - file: docker-daemon-config

