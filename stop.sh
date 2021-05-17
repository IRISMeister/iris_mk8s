#!/bin/bash
microk8s kubectl delete -f mk8s-iris.yml --wait
microk8s kubectl delete pvc --all
