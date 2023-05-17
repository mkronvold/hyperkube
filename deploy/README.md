

## kubernetes-dashboard
deploy.sh 20-kubernetes-dashboard.conf
deploy.sh 21-kubernetes-dashboard-service.conf

access at https://127.0.0.1:30002/

need secret passphrase to get past cert issue

get token to access kubernetes-dashboard

```kubectl -n kubernetes-dashboard create token admin-user```

add token to .kube/config after user certs 
token: abcd1234

