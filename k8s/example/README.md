```powershell
kubectl create namespace example
kubectl -n example apply -f https://raw.githubusercontent.com/mkronvold/hyperkube/main/k8s/example/apple.yaml
kubectl -n example apply -f https://raw.githubusercontent.com/mkronvold/hyperkube/main/k8s/example/banana.yaml
kubectl -n example apply -f https://raw.githubusercontent.com/mkronvold/hyperkube/main/k8s/example/ingress.yaml
```