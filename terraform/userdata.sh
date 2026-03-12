#!/bin/bash
# 1. Instalação do K3s
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sleep 20 

# 2. Deploy do Memos (Anotações)
cat << 'EOF' > /tmp/memos.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memos
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memos
  template:
    metadata:
      labels:
        app: memos
    spec:
      containers:
      - name: memos
        image: neosmemo/memos:latest
        ports:
        - containerPort: 5230
---
apiVersion: v1
kind: Service
metadata:
  name: memos-svc
spec:
  selector:
    app: memos
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5230
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: memos-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: memos-svc
            port:
              number: 80
EOF
kubectl apply -f /tmp/memos.yaml

# 3. Instalação do Helm e Deploy da Observabilidade
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install observability prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=traefik \
  --set grafana.ingress.paths[0]=/grafana \
  --set "grafana.grafana\.ini.server.root_url=%(protocol)s://%(domain)s/grafana/" \
  --set "grafana.grafana\.ini.server.serve_from_sub_path=true"