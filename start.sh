#!/bin/bash

./resources.sh

microk8s kubectl apply -f mk8s-iris.yml
echo "microk8s kubectl get pod -l app=iris"
echo "microk8s kubectl get statefulset -o wide"

echo "waiting until all replicas of IRIS statefulset are Ready"
# any smarter way?
count=0
while [ "$count" != "2/2" ]
do
sleep 1
count=$(microk8s kubectl get statefulset | grep data | awk '{print $2}')
done
