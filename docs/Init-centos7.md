<h1>初始化系统配置以适合docker和k8s运行</h1>

#### 所有机器关闭防火墙和SELinux

```bash
systemctl disable --now firewalld NetworkManager
setenforce 0
sed -ri '/^[^#]*SELINUX=/s#=.+$#=disabled#' /etc/selinux/config
```

#### 如果是开启了GUI环境，建议关闭dnsmasq(可选)

linux 系统开启了 dnsmasq 后(如 GUI 环境)，将系统 DNS Server 设置为 127.0.0.1，这会导致 docker 容器无法解析域名，需要关闭它.

```bash
systemctl disable --now dnsmasq
```
#### 设置时间同步客户端

```bash
yum install chrony -y
cat <<EOF > /etc/chrony.conf
server ntp.aliyun.com iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
logchange 0.5
logdir /var/log/chrony
EOF

systemctl restart chronyd
systemctl enable --now chronyd
```


#### 升级内核

```bash
yum install wget git  jq psmisc vim -y
yum install ipvsadm ipset sysstat conntrack libseccomp -y
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
yum update -y
```

- 更新完成后，需要重启

 `reboot`

- 因为目前市面上包管理下内核版本会很低,安装docker后无论centos还是ubuntu会有如下bug,4.15的内核依然存在.

```
kernel:unregister_netdevice: waiting for lo to become free. Usage count = 1
```

- 建议升级内核，耿直boy会出现更多问题

```bash
#perl是内核的依赖包,如果没有就安装下
[ ! -f /usr/bin/perl ] && yum install perl -y
#升级内核需要使用 elrepo 的yum 源,首先我们导入 elrepo 的 key并安装 elrepo 源
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
#查看可用的内核
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates
#在yum的ELRepo源中,mainline 为最新版本的内核,安装kernel

#ipvs依赖于nf_conntrack_ipv4内核模块,4.19包括之后内核里改名为nf_conntrack,但是kube-proxy的代码里没有加判断一直用的nf_conntrack_ipv4,所以这里我安装4.19版本以下的内核;
#下面链接可以下载到其他归档版本的
ubuntu  http://kernel.ubuntu.com/~kernel-ppa/mainline/
RHEL    http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/
```

- 自选版本内核安装方法

```bash
export Kernel_Vsersion=4.18.9-1
wget  http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/kernel-ml{,-devel}-${Kernel_Vsersion}.el7.elrepo.x86_64.rpm
yum localinstall -y kernel-ml*

#查看这个内核里是否有这个内核模块
find /lib/modules -name '*nf_conntrack_ipv4*' -type f
```
- 修改内核启动顺序,默认启动的顺序应该为1,升级以后内核是往前面插入,为0（如果每次启动时需要手动选择哪个内核,该步骤可以省略）

```bash
grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
#使用下面命令看看确认下是否启动默认内核指向上面安装的内核
grubby --default-kernel
```
- docker官方的内核检查脚本建议(RHEL7/CentOS7: User namespaces disabled; add 'user_namespace.enable=1' to boot command line),使用下面命令开启

```bash
grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
#重新加载内核
reboot
```

#### 设置IPVS模式加载的模块(所有机器)

```bash
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

#### 需要设定/etc/sysctl.d/k8s.conf的系统参数。

```bash
$ cat <<EOF > /etc/sysctl.d/k8s.conf
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

#### 检查系统内核和模块是否适合运行 docker (仅适用于 linux 系统)

```bash
curl https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh > check-config.sh
bash ./check-config.sh
```

#### 安装docker-ce

```bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# Step 1: 查找Docker-CE的版本:
# yum list docker-ce.x86_64 --showduplicates | sort -r
yum install docker-ce-18.09.2 -y

mkdir -p /etc/docker/
cat>/etc/docker/daemon.json<<EOF
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

# 设置docker开机启动,CentOS安装完成后docker需要手动设置docker命令补全

yum install -y  bash-completion && cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
systemctl enable --now docker
```

####  需要设定 `/etc/hosts` 解析到所有集群主机

```
192.168.88.111 k8s-m1
192.168.88.112 k8s-m2
192.168.88.113 k8s-m3
192.168.88.114 k8s-n1
```
