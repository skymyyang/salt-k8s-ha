---

## 使用[OpenVPN-Admin](https://github.com/skymyyang/OpenVPN-Admin)进行管理以及部署OpenVPN

### 简单vpn扫盲

点对点隧道协议 (PPTP) 是由包括微软和3Com等公司组成的PPTP论坛开发的一种点对点隧道协，基于拨号使用的PPP协议使用PAP或CHAP之类的加密算法，或者使用Microsoft的点对点加密算法MPPE。其通过跨越基于 TCP/IP 的数据网络创建 VPN 实现了从远程客户端到专用企业服务器之间数据的安全传输。PPTP 支持通过公共网络(例如 Internet)建立按需的、多协议的、虚拟专用网络。PPTP 允许加密 IP 通讯，然后在要跨越公司 IP 网络或公共 IP 网络(如 Internet)发送的 IP 头中对其进行封装。

![](https://lutim.cpy.re/zBVsZIfb)

之前由于使用Windows server自带的基于PPTP的VPN服务，并且使用LDAP进行管理，感觉使用起来很方便。

但是出于数据安全的考虑。建议还是使用SSLVPN。

典型的SSL VPN应用如OpenVPN，是一个比较好的开源软件。

OpenVPN提供了多种身份验证方式，用以确认参与连接双方的身份，包括：预享私钥，第三方证书以及用户名/密码组合。预享密钥最为简单，但同时它 只能用于建立点对点的VPN;基于PKI的第三方证书提供了最完善的功能，但是需要额外的精力去维护一个PKI证书体系。OpenVPN2.0后引入了用 户名/口令组合的身份验证方式，它可以省略客户端证书，但是仍有一份服务器证书需要被用作加密.

OpenVPN使用通用网络协议(TCP与UDP)的特点使它成为IPsec等协议的理想替代，尤其是在ISP(Internet service provider)过滤某些特定VPN协议的情况下。在选择协议时候，需要注意2个加密隧道之间的网络状况，如有高延迟或者丢包较多的情况下，请选择 TCP协议作为底层协议，UDP协议由于存在无连接和重传机制，导致要隧道上层的协议进行重传，效率非常低下。

### 基于Centos7部署, centos7 需要升级php版本,暂未更新

```bash
$ yum install epel-release
$ yum install openvpn httpd php-mysql mariadb-server php nodejs unzip git wget sed npm php-zip
$ npm install -g bower
$ systemctl enable mariadb
$ systemctl start mariadb
$ vim /var/www/html/info.php
测试文件内容如下：
<?php
  phpinfo();
?>
$ systemctl start httpd
# 然后在浏览器中输入你的服务器地址进行测试
http://172.16.18.186/info.php

$ mkdir ~/my_coding_workspace && cd ~/my_coding_workspace
$ git clone https://github.com/Chocobozzz/OpenVPN-Admin openvpn-admin
$ cd openvpn-admin
$ ./install.sh /var/www/html apache apache
```





### 基于Centos8部署

- 安装基础依赖

  ```shell
  # 安装epel扩展
  $ dnf install epel-release -y
  # 安装依赖工具
  $ dnf install nodejs unzip git wget sed npm net-tools
  ```

  

- 安装Apache以及Mariadb数据库，并配置PHP开发环境

  ```shell
  #安装Php以及php扩展
  $ dnf install php-json php-xml  php-mysqlnd php-mbstring  php-common  php-gd php-fpm php php-zip
  $ systemctl enable php-fpm && systemctl start php-fpm
  #安装Apache
  $ dnf install httpd -y && systemctl enable httpd && systemctl start httpd
  #安装mariadb并进行安全配置
  $ dnf install mariadb-server && systemctl enable mariadb && systemctl start mariadb
  $ mysql_secure_installation
  [root@openvpn-admin ~]$ mysql_secure_installation
  
  NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
        SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!
  
  In order to log into MariaDB to secure it, we'll need the current
  password for the root user.  If you've just installed MariaDB, and
  you haven't set the root password yet, the password will be blank,
  so you should just press enter here.
  #此处没有密码不用输入
  Enter current password for root (enter for none): 
  OK, successfully used password, moving on...
  
  Setting the root password ensures that nobody can log into the MariaDB
  root user without the proper authorisation.
  
  Set root password? [Y/n] y
  New password: 
  Re-enter new password: 
  Password updated successfully!
  Reloading privilege tables..
   ... Success!
  
  
  By default, a MariaDB installation has an anonymous user, allowing anyone
  to log into MariaDB without having to have a user account created for
  them.  This is intended only for testing, and to make the installation
  go a bit smoother.  You should remove them before moving into a
  production environment.
  
  Remove anonymous users? [Y/n] y
   ... Success!
  
  Normally, root should only be allowed to connect from 'localhost'.  This
  ensures that someone cannot guess at the root password from the network.
  
  Disallow root login remotely? [Y/n] y
   ... Success!
  
  By default, MariaDB comes with a database named 'test' that anyone can
  access.  This is also intended only for testing, and should be removed
  before moving into a production environment.
  
  Remove test database and access to it? [Y/n] y
   - Dropping test database...
   ... Success!
   - Removing privileges on test database...
   ... Success!
  
  Reloading the privilege tables will ensure that all changes made so far
  will take effect immediately.
  
  Reload privilege tables now? [Y/n] y
   ... Success!
  
  Cleaning up...
  
  All done!  If you've completed all of the above steps, your MariaDB
  installation should now be secure.
  
  Thanks for using MariaDB!
  $ vim /var/www/html/info.php
  测试文件内容如下：
  <?php
    phpinfo();
  ?>
  # 然后在浏览器中输入你的服务器地址进行测试
  http://172.16.18.186/info.php
  #开启防火墙的80端口
  $ firewall-cmd --zone=public --add-port=80/tcp --permanent
  $ firewall-cmd --reload
  ```

  可以看到如图，则表示安装成功，部署过程中遇到任何问题，可以查看apache的错误日志：

  ```shell
  $ cat /var/log/httpd/error.log
  ```

  ![](https://lutim.cpy.re/qebP1wbQ)

- 安装openVPN以及OpenVPN-admin

  ```shell
  # 安装bower
  $ npm install -g bower
  # 安装openvpn
  $ dnf install openvpn
  # 安装openvpn-admin
  $ mkdir ~/my_coding_workspace && cd ~/my_coding_workspace
  $ git clone https://github.com/Chocobozzz/OpenVPN-Admin openvpn-admin
  $ cd openvpn-admin
  $ ./install.sh /var/www/html apache apache
  #安装失败删除重试，执行如下命令删除
  $ ./desinstall.sh /var/www/html 
  #如果有前端的包安装失败，可以使用更新继续安装，也可以使用该脚本更新，不过貌似作者已经不维护了，建议熟悉php的童鞋可以继续更新
  $  ./update.sh /var/www/html
  # 在浏览器中进行安装，注意此步骤之前一定不要启动openvpn-server@server
  http://172.16.18.186/openvpn-admin/index.php?installation
  ```

- 启动openvpn-server

  ```shell
  # 修改开机启动脚本的工作目录，这里是因为我们的工作目录配置不一样
  $ vim /usr/lib/systemd/system/openvpn-server\@.service
  #将工作目录改为他的父级目录
  WorkingDirectory=/etc/openvpn
  #--explicit-exit-notify can only be used with --proto udp;此错误需要注释掉配置文件中的配置
  $ vim /etc/openvpn/server.conf
  #explicit-exit-notify 1  注释此行
  #继续修改DNS配置，确保域名解析的正确性
  push "dhcp-option DNS 223.5.5.5"
  push "dhcp-option DNS 223.6.6.6"
  #重启openvpn
  $ systemctl restart openvpn-server@server
  ```

- 配置防火墙转发规则-当然你可以选择关闭防火墙

  ```shell
  #如果使用iptables的话，请这样设置规则
  iptables -I FORWARD -i tun0 -j ACCEPT
  iptables -I FORWARD -o tun0 -j ACCEPT
  iptables -I OUTPUT -o tun0 -j ACCEPT
  
  iptables -A FORWARD -i tun0 -o $primary_nic -j ACCEPT
  iptables -t nat -A POSTROUTING -o $primary_nic -j MASQUERADE
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $primary_nic -j MASQUERADE
  iptables -t nat -A POSTROUTING -s 10.8.0.2/24 -o $primary_nic -j MASQUERADE
  
  ---
  #如果使用firewalld，可以如此设置规则
  firewall-cmd --zone=public --add-port=80/tcp --permanent
  firewall-cmd --zone=public --add-port=443/tcp --permanent
  firewall-cmd --permanent --direct --passthrough ipv4 -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens160 -j MASQUERADE
  firewall-cmd --zone=public --add-port=53/tcp --permanent
  firewall-cmd --permanent --add-service openvpn
  firewall-cmd --permanent --zone=public --add-masquerade
  firewall-cmd --reload
  firewall-cmd --query-masquerade
  firewall-cmd --list-all
  firewall-cmd --list-services
  ```

  

- 生成证书文件

  在浏览器中下载配置文件。如下图所示：

  ![](https://lutim.cpy.re/oqAs8tVH)

  ```shell
  #由于这里我们使用的openvpn-connect的gui客户端，需要合成pkcs12证书给此客户端使用。而我们所下载的配置压缩包中，只需要使用client.ovpn的配置文件即可。
  $ cd /etc/openvpn/
  $ openssl pkcs12 -export -in server.crt -inkey server.key -certfile ca.crt -name MyClient -out client.p12
  #PS:此时你可以选择输入密码，或者不输密码也行。单纯为了证书加密使用。
  ```

  

  

### 客户端部署

- 下载地址为：`https://openvpn.net/client-connect-vpn-for-windows/` 可以选择windows 客户端或者Mac客户端；我这里使用的是windows 客户端。

- 先配置证书，具体步骤如下图所示：

  ![第一步](https://lutim.cpy.re/ftbTjwC2)

  ![第二步](https://lutim.cpy.re/5NBhkPzm)

  ![第三步](https://lutim.cpy.re/XQkQIgj8)

  ![第四步](https://lutim.cpy.re/48XTQAIh)

- 导入配置文件

  ![第一步](https://lutim.cpy.re/2rS5xMQt)

  

  ![第二步](https://lutim.cpy.re/2lgAQ5b5)

  

  ![第三步](https://lutim.cpy.re/C7x1qe1C)

  ![第四步](https://lutim.cpy.re/uliUp8kX)

  ![第五步](https://lutim.cpy.re/xnuUU6ap)

  ![连通性测试](https://lutim.cpy.re/kxM1TJZB)





至此所有的步骤都已经完成了。



### tun模式以及tap模式的区别

OpenVPNserver 配置完成之后，我们可以在配置文件中可以看到OpenVPN默认工作在tun模式下。

```shell
# 通过网卡我们可以看到tun0，如果是tap模式的话，应该是tap0的网卡
$ ip ad sh
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0c:29:be:95:92 brd ff:ff:ff:ff:ff:ff
    inet 172.16.18.186/24 brd 172.16.18.255 scope global noprefixroute ens160
       valid_lft forever preferred_lft forever
    inet6 fe80::8a10:339c:e9b3:9943/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
4: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 100
    link/none 
    inet 10.8.0.1 peer 10.8.0.2/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::e92d:66d7:30b3:e5ca/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
```

- **tun模式**

  `"dev tun" will create a routed IP tunnel,`将创建可路由的 IP 隧道

  基本在所有设备上都支持

  可以透过wlan

  不会在所有网段上广播报文(广播风暴不过网关，这应该是常识了)

  tun模式的特征是三层打通，你可以当作没有二层数据。tap会处理以太网mac层；而tun不处理mac层；TUN 没有任何封装。

  因此从拨入用户那里去问内网IP的mac是多少，根本没人理你。你必须将包发到vpn网关上，交由网关转交。目标服务器还得知道回这个数据的时候，网关是vpn网关，而不是默认网关。当然，有的时候两者其实是一个，例如vpn网关在默认网关上。或者不修改每台机器配置，直接在网关上做第二跳指向。

  在 tun 模式下，protocol stack --> tun/tap 时 protocol packet 不需要增
  加任何东西，直接传给 tun/tap

  从性能上来讲 tun 的性能要好于 tap，因为没有额外的封装过程

- **tap模式**

  tap模式的特点是二层打通。典型场景是从外部打一条隧道到本地网络。进来的机器就像本地的机器一样参与通讯，你分毫看不出这些机器是在远程。

  tap在部分设备上不支持(例如移动设备)

  wlan加入网桥后不一定可以工作。

  广播包会散发到虚拟网络中，可能极大消耗流量。

  不需要在所有机器上配置或者动网关

### 客户端能够上网的关键参数

```
1. 防火墙的配置转发
2. 配置文件中的配置，如下 
   push "redirect-gateway def1"
   push "dhcp-option DNS 10.8.0.1"
```

一键安装脚本

- https://gist.github.com/aykutcan  个人未验证

参考链接：

- https://linux.cn/article-3407-1.html
- https://github.com/skymyyang/OpenVPN-Admin
- https://openvpn.net/faq/how-do-i-use-a-client-certificate-and-private-key-from-the-android-keychain/
- https://www.fandenggui.com/post/centos7-install-openvpn.html
- http://www.chenlianfu.com/?p=2699
- https://hisoka0917.github.io/linux/2017/12/21/openvpn-on-centos7/
- http://blog.shell909090.org/blog/archives/2724/

客户端下载地址：

- http://vpn.hxu.edu.cn/openvpn.html#WIN
- https://openvpn.net/client-connect-vpn-for-mac-os/  官网



本人的机构信息填写：

```
#机构信息填写
Key size (1024, 2048 or 4096) [2048]: 
Root certificate expiration (in days) [3650]:   
Certificate expiration (in days) [3650]: 
Country Name (2 letter code) [US]: CN
State or Province Name (full name) [California]: JS
Locality Name (eg, city) [San Francisco]: SZ 
Organization Name (eg, company) [Copyleft Certificate Co]: MOFANGGE
Organizational Unit Name (eg, section) [My Organizational Unit]: DEVOPS
Email Address [me@example.net]: developer@mofangge.com
Common Name (eg, your name or your server's hostname) [ChangeMe]: OPENV
```