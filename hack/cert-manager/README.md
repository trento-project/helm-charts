# Adding cert-manager for HTTPS
This guide will help you integrate cert-manager to enable HTTPS for your Trento deployment using Let's Encrypt certificates.

## Prerequisites
- Kubernetes cluster
- Helm installed
- Trento Helm chart

## Steps to Enable HTTPS

### 1. Install cert-manager CRDs
First, install the cert-manager Custom Resource Definitions (CRDs):
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.crds.yaml
```

### 2. Add jetstack repo
Add the Jetstack Helm repository and update your local Helm chart repository cache:
```
helm repo add jetstack https://charts.jetstack.io
helm repo update

```
### 3. Install cert-manager
Install cert-manager in the cert-manager namespace:
```
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.14.5
```

### 4. Configure and apply cluster-issuer
Edit `cluster-issuer.yaml` to update the email address and ingress class as needed, and apply it afterwards:
```
kubectl apply -f cluster-issuer.yaml
```

### 5. Configure and apply certificate
Edit `certificate.yaml` to update the namespace and FQDN, and apply it afterwards:
```
kubectl apply -f certificate.yaml
```

### 6. Deploy Trento with cert-manager support
Navigate to the Trento Helm chart directory and deploy it with cert-manager support enabled. Remember to change the admin password:
```
cd helm-charts-rolling/charts/trento-server
helm dependency update
helm upgrade -i trento --wait . \
         --set trento-web.adminUser.password="somepassword" \
         -f override-values.yaml
```
