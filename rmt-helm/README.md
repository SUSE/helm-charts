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
Helm from deleting them during upgrades or on `helm uninstall`. See
[Uninstalling](#uninstalling) for how to remove them manually.

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
- Setting `existingClaim` to the chart's default PVC name (`<fullname>-db` or
  `<fullname>-app`) behaves exactly like leaving it empty: the chart keeps
  creating and managing that PVC. In that case the `storage.class` and
  `storage.size` values **must match the already-deployed PVC**, because
  `storageClassName` is immutable and a PVC's requested size cannot be reduced.
  A PVC with that name that was created outside of Helm cannot be used this
  way — Helm refuses to adopt it and `helm install` fails. Give external PVCs
  a different name.

### Upgrading an existing release

This section applies when upgrading a release whose PVCs are managed by this
chart.

**No action is needed for a standard upgrade.** Leave `existingClaim` empty
(the default) and both chart-managed PVCs are preserved.

> ⚠️ Releases installed with a chart version older than 1.1.3 created their
> PVCs without the `helm.sh/resource-policy: keep` annotation. If you upgrade
> such a release and set `existingClaim` to a *different*, external PVC in the
> same step, Helm deletes the old chart-managed PVC together with its data.
> Protect it manually before upgrading:
> ```sh
> kubectl annotate pvc <fullname>-db <fullname>-app helm.sh/resource-policy=keep -n <namespace>
> ```
> Then set `existingClaim` to the new PVC name and proceed with the upgrade.
> Alternatively, first upgrade to this chart version without changing
> `existingClaim` (which adds the annotation), then switch in a second upgrade.

## Pod priority (`priorityClassName`)

Each workload can be assigned a Kubernetes
[PriorityClass](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
to influence scheduling and preemption order. These default to `""` (unset),
so no `priorityClassName` is added unless you provide one. The referenced
PriorityClass must already exist in the cluster — this chart does not create
any PriorityClass resources.

- `db.priorityClassName` PriorityClass for the MariaDB pod.
- `app.priorityClassName` PriorityClass for the RMT server pod.
- `front.priorityClassName` PriorityClass for the NGINX front pod.
- `app.cronjob.priorityClassName` PriorityClass for the sync and mirror CronJob pods.

## Deploying

`helm install rmt ./helm -f myvalues.yaml`

## Uninstalling

```sh
helm uninstall rmt -n <namespace>
```

The chart-managed PVCs (`<fullname>-db` holding the MariaDB database and
`<fullname>-app` holding the mirrored RMT repository data) are annotated with
`helm.sh/resource-policy: keep` and are **not** deleted by `helm uninstall`.
This protects the potentially large and time-consuming-to-recreate mirror data
from accidental removal. Reinstalling a release with the same name in the same
namespace re-attaches the retained PVCs.

> ⚠️ With the default `secrets.create: true`, `helm uninstall` deletes the
> chart-managed Secrets even though the PVCs are kept. On reinstall the chart
> generates new random database passwords unless you supply `db.mysql.password`
> and `db.mysql.rootPassword` explicitly — and new passwords will not match the
> credentials already stored in the retained MariaDB volume, so RMT cannot
> connect. Save the existing `<fullname>-db` credentials before uninstalling and
> re-supply them on reinstall, or manage the Secrets externally
> (`secrets.create: false`).

PVCs referenced through `existingClaim` are never managed by the chart and are
likewise left untouched.

To permanently remove the data, delete the PVCs manually after uninstalling:

```sh
kubectl get pvc -n <namespace>
kubectl delete pvc <fullname>-db <fullname>-app -n <namespace>
```

> ⚠️ Deleting the PVCs irreversibly removes the RMT database and all mirrored
> repository data. Whether the underlying PersistentVolume and its storage are
> also released depends on the PV's `reclaimPolicy`; volumes with `Retain` must
> be cleaned up separately (`kubectl delete pv <pv-name>` plus the backing
> storage).

## Further info

For more information on using RMT, refer to the [RMT Guide](https://documentation.suse.com/sles/html/SLES-all/book-rmt.html).
