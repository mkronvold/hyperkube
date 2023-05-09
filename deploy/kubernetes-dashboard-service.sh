#!/bin/bash

SRCURL="https://raw.githubusercontent.com/mkronvold/hyperv-k8s/main/k8s/kubernetes-dashboard/kubernetes-dashboard-service-np.yaml"
SRCNAME=kubernetes-dashboard-service-np.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=kubernetes-dashboard-service.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
[ -e "${PATCHNAME}" ] &&
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
