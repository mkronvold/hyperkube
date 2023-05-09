#!/bin/bash

SRCURL="https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml"
SRCNAME=metallb.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=metallb-deploy.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
[ -e "${PATCHNAME}" ] &&
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
