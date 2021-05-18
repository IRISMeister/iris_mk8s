#!/bin/bash
microk8s kubectl delete -f mk8s-iris.yml --wait
microk8s kubectl delete -f mk8s-simple.yml --wait
microk8s kubectl delete pvc --all
microk8s kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
