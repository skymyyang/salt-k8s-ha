# -*- coding: utf-8 -*-
#******************************************
# Author:       iokubernetes
# Email:        yang-li@live.cn
# Organization: iokubernetes.github.io
# Description:  Kubernetes Master
#******************************************


{% set k8s_version = "k8s-v1.18.2" %}



#接着在k8s-m1建立TLS bootstrap secret来提供自动签证使用
bootstrap-token-secret:
  file.managed:
    - name: /etc/kubernetes/bootstrap-token-secret.yaml
    - source: salt://k8s/templates/kube-api-server/bootstrap-token-secret.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        TOKEN_ID: {{ pillar['TOKEN_ID'] }}
        TOKEN_SECRET: {{ pillar['TOKEN_SECRET'] }}
  cmd.run:
    - name: /usr/local/bin/kubectl create -f /etc/kubernetes/bootstrap-token-secret.yaml
#在k8s-m1建立 TLS Bootstrap Autoapprove RBAC来自动处理 CSR
kubelet-bootstrap-rbac:
  file.managed:
    - name: /etc/kubernetes/kubelet-bootstrap-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/kubelet-bootstrap-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/local/bin/kubectl create -f /etc/kubernetes/kubelet-bootstrap-rbac.yaml

#kubectl logs 来查看,但由于 API 权限,故需要建立一个 RBAC Role 来获取存取权限,这边在k8s-m1节点执行下面命令创建
{# apiserver-to-kubelet-rbac:
  file.managed:
    - name: /etc/kubernetes/apiserver-to-kubelet-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/apiserver-to-kubelet-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /usr/local/bin/kubectl create -f /etc/kubernetes/apiserver-to-kubelet-rbac.yaml #}

#--authentication-kubeconfig 和 --authorization-kubeconfig 参数指定的证书需要有创建 "subjectaccessreviews" 的权限
{# kube-controller-manager-clusterrole:
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl create clusterrolebinding controller-manager:system:auth-delegator --user system:kube-controller-manager --clusterrole system:auth-delegator #}
