## 目的
Virtual Summit2021で、Kubernetesに関する[セッション]()を実施させていただきましたが、こちらはAzureのアカウントやiris.keyをお持ちの方が前提になっていました。
開発者の方が、少しでも気軽にKubernetesを試せるよう、仮想環境でも利用可能なmirok8sで、IRIS Community Editionを動作させる方法を記します。

参考までに私の環境は以下の通りです。
```
クライアントPC : Windows10 Pro, IP=192.168.11.5/24
mirok8s環境: 上記Windows 10上の仮想環境(Vmware player)で動作するUbuntsu 20.04.1 LTS(ubuntu-20.04.1-live-server-amd64.iso), IP=192.168.11.49/24
```

## 概要
IRIS Community EditionをKubernetesのStatefulSetとしてデプロイする手順を記します。
永続化ストレージには、microk8s_hostpathもしくはLonghornを使用します。

## インストレーション
microk8sをインストール・起動します。 実行時点では1.20.6がインストールされました。

```
$ sudo snap install microk8s --classic --channel=1.20
$ sudo usermod -a -G microk8s $USER
$ sudo chown -f -R $USER ~/.kub
$ microk8s start
$ microk8s enable dns registry storage metallb
  ・
  ・
Enabling MetalLB
Enter each IP address range delimited by comma (e.g. '10.64.140.43-10.64.140.49,192.168.0.105-192.168.0.111'):
```
ロードバランサに割り当てるIPのレンジを聞かれますので、適切な範囲を設定します。私の環境はk8s稼働環境がDefault G/W:192.168.11.1, CIDR:192.168.11.49/24ですので適当な空いているIPのレンジとして、[192.168.11.110-192.168.11.130]と指定しました。

## 起動
```
$ microk8s kubectl apply -f mk8s-iris.yml
```

補足) IRIS Community版なので、iris.keyもコンテナレポジトリにログインするためのimagePullSecretsも必要ありません。

(すべてうまく設定されていれば)しばらくするとポッドが2個作成されます。これでIRISが起動しました。
```
$ microk8s kubectl get pod
NAME     READY   STATUS    RESTARTS   AGE
data-0   1/1     Running   0          107s
data-1   1/1     Running   0          86s
$ microk8s kubectl get statefulset
NAME   READY   AGE
data   2/2     3m32s
$ microk8s kubectl get service
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)           AGE
kubernetes   ClusterIP      10.152.183.1     <none>           443/TCP           30m
iris         ClusterIP      None             <none>           52773/TCP         8m55s
iris-ext     LoadBalancer   10.152.183.137   192.168.11.110   52773:31707/TCP   8m55s
```

下記コマンドでirisにログインできます。
```
$ microk8s kubectl exec -it data-0 -- iris session iris
```

ポッドがrunningにならない場合、下記コマンドでイベントを確認できます。イメージ名を間違っていてPullが失敗したり、なんらかのリソースが不足していることが考えられます。
```
$ microk8s kubectl describe pod data-0
```

利便性のために、LoadBalancerを作成しています。192.168.11.110がアサインされていますので、下記のURLでPC上のブラウザから管理ポータルにアクセスできます。
```
http://192.168.11.110:52773/csp/sys/UtilHome.csp
ユーザ・パスワード: SuperUser/SYS
```
注意) 本来、複数のIRISインスタンスに対して付与したLoadBalancer経由で管理ポータルにアクセスすることはありません。どのポッドにアクセスするか指定できないからです。個別のポッド上のIRISインスタンスの管理ポータルにアクセスする方法は後ほどご紹介します。

どのポッドでも構わないので、データベースの構成を確認してください。下記のデータベースがPV上に作成されていることを確認できます。
```
IRISSYS 	/iris-mgr/IRIS_conf.d/mgr/
TEST-DATA 	/vol-data/TEST-DATA/
```

> まれにポータルにログインできなかったり、待たされることがあります。ライセンス不足が原因の場合があります。Community EditionはMAX 5セッションまでですので、
```
$ microk8s kubectl logs data-0
  ・
  ・
05/17/21-19:21:17:417 (2334) 2 [Generic.Event] License limit exceeded 1 times since instance start.
```

## 観察
### ストレージの場所
興味本位の観察ではありますが、/iris-mgr/はどこに存在するのでしょう？microk8sはスタンドアロンで起動するk8s環境ですので、ファイルの実体は同ホスト上にあります。まずはkubectl get pvで、作成されたPVを確認します。
```
$ microk8s kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                               STORAGECLASS        REASON   AGE
pvc-ee660281-1de4-4115-a874-9e9c4cf68083   20Gi       RWX            Delete           Bound    container-registry/registry-claim   microk8s-hostpath            37m
pvc-772484b1-9199-4e23-9152-d74d6addd5ff   5Gi        RWO            Delete           Bound    default/dbv-data-data-0             microk8s-hostpath            10m
pvc-112aa77e-2f2f-4632-9eca-4801c4b3c6bb   5Gi        RWO            Delete           Bound    default/dbv-mgr-data-0              microk8s-hostpath            10m
pvc-e360ef36-627c-49a4-a975-26b7e83c6012   5Gi        RWO            Delete           Bound    default/dbv-mgr-data-1              microk8s-hostpath            9m55s
pvc-48ea60e8-338e-4e28-9580-b03c9988aad8   5Gi        RWO            Delete           Bound    default/dbv-data-data-1             microk8s-hostpath            9m55s
```
ここで、data-0ポッドのISC_DATA_DIRECTORYに使用されている、default/dbv-mgr-data-0 をdescribeします。

```
$ microk8s kubectl describe pv pvc-112aa77e-2f2f-4632-9eca-4801c4b3c6bb
  ・
  ・
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /var/snap/microk8s/common/default-storage/default-dbv-mgr-data-0-pvc-112aa77e-2f2f-4632-9eca-4801c4b3c6bb
```
このpathが実体ファイルのありかです。
```
$ ls /var/snap/microk8s/common/default-storage/default-dbv-mgr-data-0-pvc-112aa77e-2f2f-4632-9eca-4801c4b3c6bb/IRIS_conf.d/
ContainerCheck  csp  dist  httpd  iris.cpf  iris.cpf_20210517  _LastGood_.cpf  mgr
$
```

注意) storageClassNameにhostpathは使用しないでください。microk8s_hostpathとは異なり、同じフォルダに複数IRISが同居するような状態(破壊された状態)になってしまいます。

### ホスト名の解決
StatefulSetでは、各ポットにはmetadata.nameの値に従い、data-0, data-1などのユニークなホスト名が割り当てられます。
名前解決をするために、[Headless Service](https://kubernetes.io/ja/docs/concepts/services-networking/service/#headless-service)を使用しています。これにより、各ポッド間の通信に、このホスト名を利用できます。

```
kind: StatefulSet
metadata:
  name: data
```
nslookupを使いたいのですが、kubectlやk8sで使用されているコンテナランタイム(ctr)にはdockerのようにrootでログインする機能がありません。また、IRISのイメージはセキュリティ上の理由でsudoをインストールしていませんので、追加でソフトウェアをapt installできない状態にあります。ここではbusyboxを追加で起動して、そこでnslookupを使ってホスト名を確認します。

```
$ microk8s kubectl run -i --tty --image busybox:1.28 dns-test --restart=Never --rm
/ # nslookup data-0.iris
Server:    10.152.183.10
Address 1: 10.152.183.10 kube-dns.kube-system.svc.cluster.local

Name:      data-0.iris
Address 1: 10.1.243.202 data-0.iris.default.svc.cluster.local
/ #
```
10.152.183.10はk8sが用意したDNSサーバです。data-0.irisには10.1.243.202というIPアドレスが割り当てられていることがわかります。FQDNはdata-0.iris.default.svc.cluster.localです。同様にdata-1.irisもDNSに登録されています。

## 停止
作成したリソースを削除します。
```
$ microk8s kubectl delete -f mk8s-iris.yml --wait
```
これで、IRISのポッドも削除されますが、PVは保存されたままになっていることに留意ください。これにより、次回に同じ名前のポッドが起動した際には、以前と同じボリュームが提供されます。これによりポッドのライフサイクルと、データベースのライフサイクルの分離が可能となります。次のコマンドでPVも削除出来ます(データベースの内容も永久に失われます)。

```
$ microk8s kubectl delete pvc --all
```

O/Sをシャットダウンする際には下記を実行すると、k8s環境を綺麗に停止します。
```
$ microk8s stop
```
O/S再起動後には下記コマンドでk8s環境を起動できます。
```
$ microk8s start
```

microk8s環境を完全に消去したい場合は、microk8s stopを実行する前に下記を実行します。(やたらと時間がかかりました。日頃は実行しなくて良いと思います)
```
$ microk8s reset --destroy-storage
```
## 個別のポッド上のIRISの管理ポータルにアクセスする

下記コマンドで各ポッドの内部IPアドレスを確認します。
```
$ microk8s kubectl get pod -o wide
NAME     READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
data-0   1/1     Running   0          46m   10.1.243.202   ubuntu   <none>           <none>
data-1   1/1     Running   0          45m   10.1.243.203   ubuntu   <none>           <none>
$
```
私の仮想環境のLinuxはGUIがありませんので、下記のコマンドをPCで実行することで、PC上のブラウザから管理ポータルにアクセスできるようにしました。

```
C:\temp>ssh -L 9092:10.1.243.202:52773 YourLinuxUserName@192.168.11.49
C:\temp>ssh -L 9093:10.1.243.203:52773 YourLinuxUserName@192.168.11.49
```
http://localhost:9092/csp/sys/%25CSP.Portal.Home.zen (ポッドdata-0上のIRIS)
http://localhost:9093/csp/sys/%25CSP.Portal.Home.zen (ポッドdata-1上のIRIS)


## 独自イメージを使用する場合
現在のk8sはDockerを使用していません。ですので、イメージのビルドを行うためには別途Dockerのセットアップが必要です。
> k8sはあくまで運用環境のためのものです  

ここでは、それが済んでいる前提で話を進めます。イメージはどんな内容でも構いません。ここでは例として[simple](https://github.com/IRISMeister/simple)を使用します。このイメージはMYAPPというネームスペース上で、ごく簡単なRESTサービスを提供するIRISの派生イメージです。localhost:32000はk8sが用意したコンテナレポジトリで、そこにこのイメージをpushします。

```
$ git clone https://github.com/IRISMeister/simple.git
$ cd simple
$ ./build.sh
$ docker tag dpmeister/simple:latest localhost:32000/simple:latest
$ docker push localhost:32000/simple:latest
```
> ビルド行程がご面倒であれば、ビルド済みのイメージがdpmeister/simple:latestとして保存してありますので、下記のようにpullして、そのまま使用することも可能です。でも内容のわからないイメージって...ちょっと気持ち悪いですよね。
```
$ docker pull dpmeister/simple:latest
$ docker tag dpmeister/simple:latest localhost:32000/simple:latest
$ docker push localhost:32000/simple:latest
```

ymlを編集してimageをlocalhost:32000/simpleに書き換えます。データの保存場所をコンテナ内のデータベースから外部データベースに切り替えるために、cpfのactionにModifyNamespaceを追加します。編集済みのファイルをmk8s-simple.ymlとしてご用意しました(mk8s-iris.ymlとほとんど同じです)。これを使用して起動します。
```
$ microk8s kubectl apply -f mk8s-simple.yml
$ microk8s kubectl get svc
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)           AGE
kubernetes   ClusterIP      10.152.183.1     <none>           443/TCP           3h36m
iris         ClusterIP      None             <none>           52773/TCP         20m
iris-ext     LoadBalancer   10.152.183.224   192.168.11.110   52773:30308/TCP   20m
$
$ curl -s -H "Content-Type: application/json; charset=UTF-8" -H "Accept:application/json" "http://192.168.11.110:52773/csp/myapp/get" --user "appuser:SYS" | python3 -mjson.tool
{
    "HostName": "data-1",
    "UserName": "appuser",
    "Status": "OK",
    "TimeStamp": "05/17/2021 19:34:00",
    "ImageBuilt": "05/17/2021 10:06:27"
}
```
curlコマンドを繰り返すと、HostNameがdata-0だったりdata-1だったりしますが、これは(期待通りに)ロードバランスされているためです。


## Longhornを使用する場合

longhornを起動し、すべてのポッドがREADYになるまで待ちます。
```
$ microk8s kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
$ microk8s kubectl -n longhorn-system get pods
NAME                                       READY   STATUS    RESTARTS   AGE
longhorn-ui-5b864949c4-72qkz               1/1     Running   0          4m3s
longhorn-manager-wfpnl                     1/1     Running   0          4m3s
longhorn-driver-deployer-ccb9974d5-w5mnz   1/1     Running   0          4m3s
instance-manager-e-5f14d35b                1/1     Running   0          3m28s
instance-manager-r-a8323182                1/1     Running   0          3m28s
engine-image-ei-611d1496-qscbp             1/1     Running   0          3m28s
csi-attacher-5df5c79d4b-gfncr              1/1     Running   0          3m21s
csi-attacher-5df5c79d4b-ndwjn              1/1     Running   0          3m21s
csi-provisioner-547dfff5dd-pj46m           1/1     Running   0          3m20s
csi-resizer-5d6f844cd8-22dpp               1/1     Running   0          3m20s
csi-provisioner-547dfff5dd-86w9h           1/1     Running   0          3m20s
csi-resizer-5d6f844cd8-zn97g               1/1     Running   0          3m20s
csi-resizer-5d6f844cd8-8nmfw               1/1     Running   0          3m20s
csi-provisioner-547dfff5dd-pmwsk           1/1     Running   0          3m20s
longhorn-csi-plugin-xsnj9                  2/2     Running   0          3m19s
csi-snapshotter-76c6f569f9-wt8sh           1/1     Running   0          3m19s
csi-snapshotter-76c6f569f9-w65xp           1/1     Running   0          3m19s
csi-attacher-5df5c79d4b-gcf4l              1/1     Running   0          3m21s
csi-snapshotter-76c6f569f9-fjx2h           1/1     Running   0          3m19s
```

mk8s-iris.ymlの全てのstorageClassNameをlonghornに変更してください。
もし、microk8s_hostpathで既に起動しているのであれば、ポッド、PVともに全て削除したうえで、上述の手順を実行してください。つまり...

```
$ microk8s kubectl delete -f mk8s-iris.yml --wait
$ microk8s kubectl delete pvc --all
   mk8s-iris.yml編集
      前)storageClassName: microk8s-hostpath
      後)storageClassName: longhorn

$ microk8s kubectl apply -f mk8s-iris.yml
```
