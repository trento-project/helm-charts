1. Install CRDs:
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.crds.yaml
2. Add jetstack repo:
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
3. Install cert-manager
   helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.14.5
4. Apply cluster-issuer:
   kubectl apply -f cluster-issuer.yaml
5. Apply certificate:
   kubectl apply -f certificate.yaml
6. Update the email and FQDN values in certificate.yaml, cluster-issuer.yaml and override-values.yaml
7. Deploy trento with certmanager support enabled:
   cd helm-charts-rolling/charts/trento-server
   helm dependency update
   helm upgrade -i trento --wait . \
            --set trento-web.adminUser.password="${{ secrets.DEMO_PASSWORD }}" \
            --set trento-web.image.pullPolicy=Always \
            --set trento-web.image.repository="${IMAGE_REPOSITORY}/trento-web" \
            --set trento-web.image.tag="demo" \
            --set trento-wanda.image.pullPolicy=Always \
            --set trento-wanda.image.repository="${IMAGE_REPOSITORY}/trento-wanda" \
            --set trento-wanda.image.tag="demo" \
            -f override-values.yaml