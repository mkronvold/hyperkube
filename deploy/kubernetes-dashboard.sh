#!/bin/bash

SRCURL="https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml"
SRCNAME=recommended.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=kubernetes-dashboard.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
