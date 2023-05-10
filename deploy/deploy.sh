#!/bin/bash

[ "${1}" ] && NAME="${1}" || exit 1

[ "$SRCURL" ] || exit 1
[ "$SRCNAME" ] || exit 1
[ "$PATCHNAME" ] || exit 1
[ "$DEPLOYNAME" ] || exit 1
[ "$KUBECTLOPTIONS" ] || exit 1

rm -f $SRCNAME
wget "$SRCURL"
[ -e "${PATCHNAME}" ] && patch $SRCNAME < $PATCHNAME
mv $SRCNAME $DEPLOYNAME
kubectl apply -f $DEPLOYNAME $KUBECTLOPTIONS
