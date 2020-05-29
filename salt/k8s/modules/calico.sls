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