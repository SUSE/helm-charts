# Purpose

This chart deploys a SUSE Repository Mirroring Tool (RMT) server on Kubernetes.
It is tested on K3s but should work on any Kubernetes distribution.

## Overview

To deploy SUSE RMT on top of Kubernetes, each component of the stack is deployed in a dedicated container using a
Helm chart.

### Repository Mirroring Tool (SUSE RMT) server

A containerized version of the SUSE RMT application that can pass its configuration via Helm values. Because persistent storage resides on a persistent volume, you need to adjust the volume size according to the number of repositories you need to mirror.

### MariaDB

The database back-end for SUSE RMT.
If needed, RMT creates the database and tables at startup, so no specific
post-installation task is required for it to be usable. Passwords are
self-generated, unless explicitly specified in the values file, or
provided via externally-managed Secrets (see
[Externally-managed Secrets](#externally-managed-secrets)).

### NGINX

The web server with appropriate configuration for RMT routes. Having a correctly
configured web server right from the start allows you to target your ingress traffic
(for RMT) to directly to the server. You don't have to configure ingress for RMT specific
paths handling, as NGINX is configured to do that.

## Prerequisites

- a running Kubernetes cluster
- helm command configured to interact with the cluster

The Helm chart can be obtained using the following command:

`helm pull oci://registry.suse.com/suse/rmt-helm`

## Custom mandatory values

Certain values of the chart do not have any defaults:
- SCC mirroring credentials (refer to [more information](https://documentation.suse.com/sles/html/SLES-all/cha-rmt-mirroring.html#sec-rmt-mirroring-credentials) for more information) — required only when `secrets.create` is `true` (the default). When Secrets are managed externally, see [Externally-managed Secrets](#externally-managed-secrets).
- list of products to mirror
- list of products not to mirror
- list of repos to mirror
- list of repos not to mirror
- DNS name used to reach the RMT server
- configured [storage](https://kubernetes.io/docs/concepts/storage/)

Before deploying the chart, you must fill a custom values file.

The following example enables ingress with TLS. The `create-certs.sh` script
supplied with the Helm chart can be used
to create self-signed certificates and add them to Kubernetes as a usable TLS
secret.

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
    repos_enable:
      - 1743 # SLE-Live-Patching12-Pool for sle-12-x86_64
      - 7434
      - 7437
    repos_disable:
      - 7940
front:
  enabled: true
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

The required values in the custom value file are as follows:

- `app.scc.password` SUSE Customer Center proxy password. Required only when `secrets.create` is `true` (the default). The password string must be in quotes. If the quote character `"` is part of the string, it has to be escaped with `\`.
- `app.scc.username` SUSE Customer Center proxy user name. Required only when `secrets.create` is `true` (the default). The user name string must be quotes. If the quote character `"` is part of the string, it has to be escaped with `\`.
- `app.scc.products_enable` List of products to enable for mirroring.
- `app.scc.products_disable` list of products to exclude from mirroring.
- `app.scc.repos_enable` List of repos to enable for mirroring.
- `app.scc.repos_disable` List of repos to exclude from mirroring.
- `app.storage.class` Kubernetes storageclass.
- `db.storage.class` Kubernetes storageclass.
- `front.enabled` Enable or disable front.
- `ingress.enabled` Enable or disable ingress. Also enable "front" if you want "ingress".
- `ingress.hosts[0]` DNS name at which the RMT service is be accessible from clients.
- `ingress.tls[0].hosts[0]` DNS name at which the RMT service is be accessible from clients.
- `ingress.tls[0].secretName` TLS ingress certificate.

## Secret names and external Secret management

By default (`secrets.create: true`) this chart renders two Kubernetes Secrets.
Their names are derived from `define "rmt.fullname"` (defined in `templates/_helpers.tpl`),
suffixed with `-db` and `-app`:

- `<fullname>-db` — keys: `password`, `rootPassword` (MariaDB credentials)
- `<fullname>-app` — keys: `username`, `password` (SCC credentials)

For the common case `helm install rmt ./rmt-helm`, the names resolve to
`rmt-db` and `rmt-app` — the same names referenced by the Deployment and
CronJob templates. When the chart creates the Secrets itself
(`secrets.create: true`), these default names are always used.

### Externally-managed Secrets

To let another component (for example, HashiCorp Vault Secrets Operator managed
by a separate Helm chart) own those Secrets, set `secrets.create: false`. In
that mode you may point the chart at pre-existing Secrets that use self-defining
names via `secrets.existingDbSecret` and `secrets.existingAppSecret`:

```yaml
secrets:
  create: false
  existingDbSecret: rmt-vault-db
  existingAppSecret: rmt-vault-scc
```

When `secrets.create` is `false`:

- This chart no longer renders `10-db-secrets.yaml` / `20-app-secrets.yaml`.
- `app.scc.username` and `app.scc.password` are no longer required in your
  values file — they must be present in the externally-created Secret instead.
- You must ensure the required Secrets already exist in the target namespace
  **before** installing this chart, with these keys:

  | Secret name | Keys |
  |---|---|
  | `existingDbSecret` (default `<fullname>-db`) | `password`, `rootPassword` |
  | `existingAppSecret` (default `<fullname>-app`) | `username`, `password` |

## Using existing PersistentVolumeClaims

By default, the chart creates and manages two PVCs:

- `<fullname>-db` — used by MariaDB
- `<fullname>-app` — used by the RMT server and its cronjobs

Both PVCs are annotated with `helm.sh/resource-policy: keep`, which prevents
Helm from deleting them during upgrades or uninstalls.

### Mounting an external PVC

To mount a **pre-existing PVC** that was created outside this chart (for example,
a PVC bound to a statically provisioned PV, or one managed by a parent chart),
set `db.storage.existingClaim` and/or `app.storage.existingClaim` to the name
of that PVC. The chart will then skip creating its own PVC for that component
and mount the specified claim instead.

```yaml
db:
  storage:
    existingClaim: <my-external-db-pvc>
app:
  storage:
    existingClaim: <my-external-app-pvc>
```

Notes:

- The referenced PVCs must already exist in the same namespace before install.
- When `existingClaim` is set to an external name, its `storage.class`,
  `storage.size`, and (for `app`) `storage.accessModes` values are ignored —
  the existing PVC's own spec applies.
- `db.storage.existingClaim` and `app.storage.existingClaim` are independent:
  you can override one while letting the chart manage the other.

### Upgrading an existing release
The session applys to the scenario that: the live release in K8s cluster using PVCs managed by this helm chart, then need an upgrade.

**No action is needed for a standard upgrade.** Leave `existingClaim` empty
(the default) and both chart-managed PVCs are preserved

> ⚠️ If you need to switch a component to a *different*, external PVC after
> the chart has already created one, manually protect the chart-managed PVC
> before upgrading, otherwise Helm will delete it:
> ```sh
> kubectl annotate pvc <fullname>-db <fullname>-app helm.sh/resource-policy=keep -n <namespace name>
> ```
> Then set `existingClaim` to the new PVC name and proceed with the upgrade.

> ⚠️ If you set `existingClaim` to the same name as the default PVC created by
> the chart, such as `<fullname>-app`, `helm upgrade` use the chart's own PVC, instead of PVC that has the same name
> but was created outside of this Helm chart. In this case, the `storage.class`
> and `storage.size` values you supply **must match the already-deployed PVC**,
> because `storageClassName` is immutable in a PVC's spec, as is the storage size.

## Deploying

`helm install rmt ./helm -f myvalues.yaml`

## Further info

For more information on using RMT, refer to the [RMT Guide](https://documentation.suse.com/sles/html/SLES-all/book-rmt.html).
