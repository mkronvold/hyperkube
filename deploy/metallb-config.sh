#!/bin/bash

SRCURL="https://raw.githubusercontent.com/mkronvold/hyperkube/main/k8s/Ingress-nginx/metallb-config.yaml"
SRCNAME=metallb-config.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=metallb-config.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
[ -e "${PATCHNAME}" ] &&
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
