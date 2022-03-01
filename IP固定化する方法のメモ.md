# VMWAREでNAT接続したvmのIPを固定する方法のメモ書き
なんらかのクラスタを構成する場合(今回はk8sクラスタ)、IPは固定しておかないとトラブルのもとです。

1. dhcpの範囲,DNS,Default G/Wを確認する。
```
C:\ProgramData\VMware\vmnetdhcp.conf
# Virtual ethernet segment 8
 range 192.168.211.128 192.168.211.254; 　<==DHCP 範囲
 option domain-name-servers 192.168.211.2;　<==DNSサーバ
```
固定IPには、192.168.211.10～など、この範囲以外のIPを使用する。

C:\ProgramData\VMware\vmnetnat.conf
```
# NAT gateway address
ip = 192.168.211.2/24  <==Default G/W
```

2. IPを固定化
```
ubuntu20.04LTS
Subnet CIDR: 192.168.211.0/24
$ vi /etc/netplan/99-netcfg.yaml
network:
    version: 2
    ethernets:
        ens32:
            dhcp4: false
            addresses: [192.168.211.10/24]
            gateway4: 192.168.211.2
            nameservers:
                addresses: [192.168.211.2]
                search: []
            optional: true
$ sudo netplan apply
$ ping 192.168.211.2
  [成功するはず]
```
これだけだとDNS名前解決が失敗する。

3. DNS設定変更

下記を実行。
```
$ sudo su -
$ vi /etc/systemd/resolved.conf
DNSStubListener=no

$ cd /etc
$ ln -sf ../run/systemd/resolve/resolv.conf resolv.conf
$ systemctl restart systemd-resolved.service

$ vi /etc/resolv.conf
nameserver 192.168.211.2  <== netplan/99-netcfg.yamlで指定した値になってるはず。
```

4. hostname変更
3ホスト用意したので各ホストで下記を実行
```
host1$ sudo hostnamectl set-hostname ubuntu-1
host2$ sudo hostnamectl set-hostname ubuntu-2
host3$ sudo hostnamectl set-hostname ubuntu-3
```

5. hostsに全ホストを追加
192.168.211.2(vmwareのDNS)は、上記ホスト名を解決できないので下記を追加。
```
$ sudo vi /etc/hosts
192.168.211.10 ubuntu-1
192.168.211.11 ubuntu-2
192.168.211.12 ubuntu-3
```
