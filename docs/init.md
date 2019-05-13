
# 系统环境初始化

## 0.升级内核(所有机器)

<table border="0">
       <tr>
           <td><a href="docs/update-kernel.md">升级内核文档</a></td>
       </tr>
</table>

- 设置/etc/hosts保证主机名能够解析

```bash
[root@linux-node1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.150.141 linux-node1
192.168.150.142 linux-node2
192.168.150.143 linux-node3
192.168.150.144 linux-node4
```

- 设置部署节点到其它所有节点的SSH免密码登录（包括本机）
```Bash
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
[root@linux-node1 ~]# ssh-copy-id linux-node4
[root@linux-node1 ~]# scp /etc/hosts linux-node2:/etc/
[root@linux-node1 ~]# scp /etc/hosts linux-node3:/etc/
[root@linux-node1 ~]# scp /etc/hosts linux-node4:/etc/
```

- 设置 rsyslogd 和 systemd journald

 systemd 的 journald 是 Centos 7 缺省的日志记录工具，它记录了所有系统、内核、Service Unit 的日志。
 相比 systemd，journald 记录的日志有如下优势
 1. 可以记录到内存或文件系统；(默认记录到内存，对应的位置为 /run/log/jounal)
 2. 可以限制占用的磁盘空间、保证磁盘剩余空间
 3. 可以限制日志文件大小、保存的时间

journald 默认将日志转发给 rsyslog，这会导致日志写了多份，/var/log/messages 中包含了太多无关日志，不方便后续查看，同时也影响系统性能

```Bash
mkdir /var/log/journal # 持久化保存日志的目录
mkdir /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-prophet.conf <<EOF
[Journal]
# 持久化保存到磁盘
Storage=persistent

# 压缩历史日志
Compress=yes

SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000

# 最大占用空间 10G
SystemMaxUse=10G

# 单日志文件最大 200M
SystemMaxFileSize=200M

# 日志保存时间 2 周
MaxRetentionSec=2week

# 不将日志转发到 syslog
ForwardToSyslog=no
EOF
systemctl restart systemd-journald
```



## 1.安装Docker(所有机器)

第一步：使用国内Docker源

```Bash
[root@linux-node1 ~]# cd /etc/yum.repos.d/
[root@linux-node1 yum.repos.d]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

第二步：Docker安装：

```Bash
[root@linux-node1 ~]# yum install docker-ce-18.09.2
[root@linux-node1 ~]# mkdir -p /etc/docker/
[root@linux-node1 ~]# cat>/etc/docker/daemon.json<<EOF
{
  "registry-mirrors": ["https://fz5yth0r.mirror.aliyuncs.com"],
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
```

第三步：启动后台进程

设置docker开机启动,CentOS安装完成后docker需要手动设置docker命令补全
```Bash
[root@linux-node1 ~]# yum install -y  bash-completion && cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
[root@linux-node1 ~]# systemctl start docker && systemctl enable docker
```

## 2.准备部署目录(所有机器)

```Bash
mkdir -p /opt/kubernetes/{cfg,bin,ssl,log}
```

## 3.准备软件包

- 百度网盘下载地址：

Kubernetes二进制文件下载地址： 链接：`https://pan.baidu.com/s/1aIfj-8Zo26bPo_3cXFhkXA `
提取码：`xwjh`

- GitHub下载地址：

1. kubernetes：https://github.com/kubernetes/kubernetes 点击CHANGELOG-Version.md即可看到对版本的下载链接。这里我们下载serve即可。
2. CFSSL地址：https://pkg.cfssl.org/
3. etcd地址：https://github.com/etcd-io/etcd/releases
4. CNI插件：https://github.com/containernetworking/plugins/releases
5. flannel：https://github.com/coreos/flannel/releases


## 4.解压软件包

```
 # tar zxf kubernetes-server-linux-amd64.tar.gz
```

## 5.配置内核参数(所有机器)

```Bash
[root@linux-node1 ~]# cat <<EOF > /etc/sysctl.d/k8s.conf
# https://github.com/moby/moby/issues/31208
# ipvsadm -l --timout
# 修复ipvs模式下长连接timeout问题 小于900即可
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
# 要求iptables不对bridge的数据进行处理
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.netfilter.nf_conntrack_max = 2310720
fs.inotify.max_user_watches=89100
fs.may_detach_mounts = 1
fs.file-max = 52706963
fs.nr_open = 52706963
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF

$ sysctl --system
```
## 6.设置IPVS模式加载的模块(所有机器)

```Bash
yum install ipvsadm ipset sysstat conntrack libseccomp -y
$ :> /etc/modules-load.d/ipvs.conf
$ module=(
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
br_netfilter
  )
$ for kernel_module in ${module[@]};do
    /sbin/modinfo -F filename $kernel_module |& grep -qv ERROR && echo $kernel_module >> /etc/modules-load.d/ipvs.conf || :
done
$ systemctl enable --now systemd-modules-load.service
```
