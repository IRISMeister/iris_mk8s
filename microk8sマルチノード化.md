# microk8sマルチノード化の手順

## マスターノード
(もし未実行であれば)1台目で実行
```bash
irismeister@ubuntu-1:~$ microk8s enable dns registry storage metallb:192.168.120.110-192.168.120.130

irismeister@ubuntu-1:~$ kubectl get node
NAME       STATUS   ROLES    AGE    VERSION
ubuntu-1   Ready    <none>   5m9s   v1.20.13-35+d877e7a8ac536e
```

## ノード追加
1台目で実行
```bash
irismeister@ubuntu-1:~$ microk8s add-node
From the node you wish to join to this cluster, run the following:
microk8s join 192.168.120.10:25000/xxxxx
```
2台目で実行
```bash
irismeister@ubuntu-2:~$ sudo snap install microk8s --classic --channel=1.20
irismeister@ubuntu-2:~$ microk8s start
irismeister@ubuntu-2:~$ microk8s join 192.168.120.10:25000/xxxxx 
Contacting cluster at 192.168.120.10
Waiting for this node to finish joining the cluster. .. .. ..
irismeister@ubuntu-2:~$
```
1台目で実行
```bash
irismeister@ubuntu-1:~$ kubectl get node
NAME       STATUS   ROLES    AGE   VERSION
ubuntu-1   Ready    <none>   10m   v1.20.13-35+d877e7a8ac536e
ubuntu-2   Ready    <none>   32s   v1.20.13-35+d877e7a8ac536e
```

3台目以降、同様にmicrok8s add-nodeからの手順を実行する。

## 特定ノードをスケジューリング対象からはずす方法
```bash
irismeister@ubuntu-1:~$ kubectl cordon ubuntu-2
irismeister@ubuntu-1:~$ kubectl drain --ignore-daemonsets ubuntu-2
```
スケジューリングを再開するには
```bash
irismeister@ubuntu-1:~$ kubectl uncordon ubuntu-2
```


## ノード削除
削除するノード(ubuntu-3)で実行
```bash
irismeister@ubuntu-3:~$ microk8s leave
```
残りのノードで実行
```bash
irismeister@ubuntu-1:~$ microk8s remove-node ubuntu-3
irismeister@ubuntu-2:~$ microk8s remove-node ubuntu-3
```
