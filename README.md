# Purpose

This chart is used to deploy and RMT server on top of a kubernetes cluster.
It has been developped on a k3s based cluster but should work on any of them.

# Prerequisites

- a running kubernetes cluster
- helm (v3) command configured to interact with this cluster

# Custom mandatory values

Some values of this chart do not have any sensible defaults:
- SCC credentials
- list of products to mirror
- list of products to not mirror
- DNS name the RMT server should be reachable at

You should fill a custom values file before deploying the chart.

Below example also enables ingress with TLS.
The create-certs.sh can be used to create self-signed certificates and
add them to Kubernetes as a usable TLS secret.

```
cat << EOF > myvalues.yaml
---
app:
  scc:
    username: UXXXXXXX
    password: PASSXXXX
    products_enable:
      - SLES/15.3/x86_64
      - sle-module-python2/15.3/x86_64
    products_disable:
      - sle-module-legacy/15.3/x86_64
      - sle-module-cap-tools/15.3/x86_64
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
```


#

# Deploying

`helm install rmt ./helm -f myvalues.yaml`
