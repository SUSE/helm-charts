# Purpose

This chart is used to deploy and RMT server on top of a kubernetes cluster.
It has been developped on a k3s based cluster but should work on any of them.

# Overview

Every component of the stack is defined in its own container, and Helm is used to ease deployment on top of Kubernetes.

## RMT server

A containerized version of the rmt application, with the ability to pass its configuration via Helm values.
Storage is done on a volume, thus you need to adapt its size depending on the number of repositories you need to mirror.

## MariadDB

The database backend for RMT.
RMT does create the database/tables at startup if needed so no specific post-installation task is required for it to be usable.
Passwords are self-generated unless explicitely specified in the values file.

## Nginx

The web server with proper configuration for RMT routes.
Having a properly configured webserver out of the box allows you to target your ingress traffic (for RMT) to it directly. You don't have to configure ingress for RMT specific paths handling, as Nginx is configured to do so.

# Prerequisites

- a running kubernetes cluster
- helm (v3) command configured to interact with this cluster

# Custom mandatory values

Some values of this chart do not have any sensible defaults:
- SCC mirroring credentials, please have a look here for [more information](https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-rmt-mirroring.html#sec-rmt-mirroring-credentials)
- list of products to mirror
- list of products to not mirror
- DNS name the RMT server should be reachable at
- Configured [storage](https://kubernetes.io/docs/concepts/storage/)

You should fill a custom values file before deploying the chart.

Below example also enables ingress with TLS.
The create-certs.sh can be used to create self-signed certificates and
add them to Kubernetes as a usable TLS secret.

```
cat << EOF > myvalues.yaml
---
app:
  storage:
    class: my-storage-class
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
db:
  storage:
    class: my-storage-class
EOF
```


#

# Deploying

`helm install rmt ./helm -f myvalues.yaml`
