## 基于 nginx 代理的 kube-apiserver 高可用方案

- 控制节点的 kube-controller-manager、kube-scheduler 是多实例部署，所以只要有一个实例正常，就可以保证高可用
- 集群内的 Pod 使用域名 kubernetes 访问 kube-apiserver， kube-dns 会自动解析出多个 kube-apiserver 节点的 IP，所以也是高可用的
- kubelet、kube-proxy、controller-manager、scheduler 通过本地的 kube-nginx（监听 127.0.0.1）访问 kube-apiserver，从而实现 kube-apiserver 的高可用
- kube-nginx 会对所有 kube-apiserver 实例做健康检查和负载均衡
- 需要在所有节点上安装nginx

## 下载和编译 nginx

- 下载源码

```Bash
cd /usr/local/src
wget http://nginx.org/download/nginx-1.15.3.tar.gz
tar -xzvf nginx-1.15.3.tar.gz
```

- 配置编译参数

`--with-stream` : 开启 4 层透明转发(TCP Proxy)功能

`--without-xxx` : 关闭所有其他功能，这样生成的动态链接二进制程序依赖最小

```Bash
mkdir /opt/kubernetes/kube-nginx
cd /usr/local/src/nginx/nginx-1.15.3
./configure --with-stream --without-http --prefix=/opt/kubernetes/kube-nginx --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module
make && make install
```
- 验证编译的nginx

```Bash
/opt/kubernetes/kube-nginx/sbin/nginx -v
ldd /opt/kubernetes/kube-nginx/sbin/nginx
## 由于只开启了 4 层透明转发功能，所以除了依赖 libc 等操作系统核心 lib 库外，没有对其它 lib 的依赖(如 libz、libssl 等)，这样可以方便部署到各版本操作系统中
```

## 配置文件`kube-nginx.conf`

- 配置nginx，开启4层透明转发功能;需要根据集群 kube-apiserver 的实际情况，替换 backend 中 server 列表

```Bash
cat /opt/kubernetes/kube-nginx/conf/kube-nginx.conf <<EOF
worker_processes auto;

events {
    worker_connections  10240;
    use epoll;
}
error_log /var/log/nginx_error.log info;
stream {
    upstream kube-servers {
        hash $remote_addr consistent;
        server 192.168.150.141:6443          max_fails=3 fail_timeout=30s;
        server 192.168.150.142:6443         max_fails=3 fail_timeout=30s;
        server 192.168.150.143:6443        max_fails=3 fail_timeout=30s;
    }

    server {
        listen 127.0.0.1:8443;
        proxy_connect_timeout 1s;
        proxy_timeout 30s;
        proxy_pass kube-servers;
    }
}
EOF
```
## 配置开机启动

- 配置 kube-nginx systemd unit 文件

```Bash
cat > /usr/lib/systemd/system/kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/opt/kubernetes/kube-nginx/sbin/nginx -c /opt/kubernetes/kube-nginx/conf/kube-nginx.conf -p /opt/kubernetes/kube-nginx -t
ExecStart=/opt/kubernetes/kube-nginx/sbin/nginx -c /opt/kubernetes/kube-nginx/conf/kube-nginx.conf -p /opt/kubernetes/kube-nginx
ExecReload=/opt/kubernetes/kube-nginx/sbin/nginx -c /opt/kubernetes/kube-nginx/conf/kube-nginx.conf -p /opt/kubernetes/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```
- 启动 kube-nginx 服务

```Bash
systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx
```

## 检查 kube-nginx 服务运行状态

```Bash
systemctl status kube-nginx |grep 'Active:'
journalctl -u kube-nginx
```
