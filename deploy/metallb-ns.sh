#!/bin/bash

SRCURL="https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml"
SRCNAME=namespace.yaml
PATCHNAME=${SRCNAME}.patch
DEPLOYNAME=metallb-ns.yaml
KUBECTLOPTIONS="--insecure-skip-tls-verify=true"

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
