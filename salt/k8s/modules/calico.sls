#这里我们使用calico网络插件
calico-yaml-install:
  file.managed:
    - name: /etc/kubernetes/calico.yaml
    - source: salt://k8s/templates/calico/calico.yaml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        POD_CIDR: {{ pillar['POD_CIDR'] }}
        VIP_IF: {{ pillar['VIP_IF'] }}
  cmd.run: 
    - name: /usr/local/bin/kubectl apply -f  /etc/kubernetes/calico.yaml

#这里部署coredns插件
coredns-yaml-install:
  file.managed:
    - name: /etc/kubernetes/coredns.yaml
    - source: salt://k8s/templates/calico/coredns.yaml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        CLUSTER_DNS_DOMAIN: {{ pillar['CLUSTER_DNS_DOMAIN'] }}
        CLUSTER_DNS_SVC_IP: {{ pillar['CLUSTER_DNS_SVC_IP'] }}
  cmd.run: 
    - name: /usr/local/bin/kubectl apply -f  /etc/kubernetes/coredns.yaml