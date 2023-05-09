#!/bin/bash

SRCURL="https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
SRCNAME=components.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=kubernetes-metrics.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
