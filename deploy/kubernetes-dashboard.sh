#!/bin/bash

rm -f recommend.yaml kubernetes-dashboard-service-np.yaml
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
wget https://raw.githubusercontent.com/mkronvold/hyperv-k8s/main/k8s/kubernetes-dashboard/kubernetes-dashboard-service-np.yaml
#patch recommended.yaml <<EOF
#EOF
mv recommended.yaml kubernetes-dashboard.yaml
#patch kubernetes-dashboard-service-np.yaml <<EOF
#EOF
mv kubernetes-dashboard-service-np.yaml kubernetes-dashboard-service.yaml

kubectl apply -f kubernetes-dashboard.yaml
kubectl apply -f kubernetes-dashboard-service.yaml
