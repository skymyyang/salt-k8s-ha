<h1>初始化系统配置以适合docker和k8s运行</h1>

#### 所有机器关闭防火墙和SELinux

```bash
systemctl disable --now firewalld NetworkManager postfix
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
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
```

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


#### 检查系统内核和模块是否适合运行 docker (仅适用于 linux 系统)

```bash
curl https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh > check-config.sh
bash ./check-config.sh
```

####  需要设定 `/etc/hosts` 解析到所有集群主机

```
192.168.150.141 linux-node1
192.168.150.142 linux-node2
192.168.150.143 linux-node3
192.168.150.144 linux-node4
```
