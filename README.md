# helm

Helm chart to deploy rmt server.

Based on work from Thorsten Kukuk https://github.com/thkukuk/rmt-container

# Custom mandatory values

You should pass credentials to SCC in a custom values file.

Below example also enables ingress with TLS.
The create-certs.sh can be used to create self-signed certificates and
add them to Kubernetes as a usable TLS secret.

cat << EOF > myvalues.yaml
---
app:
  scc:
    username: UXXXXXXX
    password: PASSXXXX
ingress:
  enabled: true
  hosts:
    - host: chart-example.local
      paths:
        - path: "/"
          pathType: Prefix
  tls:
  - secretName: rmt-cert
    hosts:
    - chart-example.local
EOF

#

# Deploying
helm install rmt ./helm -f myvalues.yaml
