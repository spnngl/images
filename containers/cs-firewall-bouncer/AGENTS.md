# cs-firewall-bouncer

CrowdSec's nftables bouncer, one static Go binary built from source on
`scratch`. It pulls the bans of a CrowdSec Local API (LAPI, not in this
repository) and drops those sources in its own nftables tables, `ip
crowdsec` and `ip6 crowdsec6`, hooked at `input` and `forward`, priority
-10, before firewalld. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Runtime contract

podman, rootful:

- host network, root, `--cap-drop all --cap-add NET_ADMIN`,
  `--read-only`, `--security-opt no-new-privileges`,
  `--security-opt label=disable`
- `API_URL` and `API_KEY` (a podman secret) from the runtime; plain HTTP
  to the LAPI (no CA bundle)
- overrides: one file mounted `:ro`, no `:Z`, at
  `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml.local` (the
  host's `/etc/crowdsec/firewall-bouncer.yaml`), deep-merged: maps
  merge, scalars and lists are replaced. To replace the config, mount a
  file and pass `-c <path>`.
- metrics on `127.0.0.1:60601` of the host
- the admin's IP allowlisted on the LAPI, or a ban locks out sshd
  (42022)

Kill switch: stop the container; a graceful stop deletes the tables.
Leave the tables alone while it runs: it doesn't recreate a deleted one.

## Rules

- Keep `retry_initial_connect: true`.
- The last instruction is the smoke test `-T`, never `-t`: `-t` creates
  the tables and deletes them on exit, the running bouncer's included.

## Updates

Never automerged: port upstream's `config/crowdsec-firewall-bouncer.yaml`
changes between the two tags to
`sysroot/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`.

## Limits

On `kubeenv` hosts, Cilium's `kubeProxyReplacement` handles NodePort and
LoadBalancer traffic in eBPF, before netfilter: the bouncer only covers
the host's own services (sshd, the k3s API, `hostNetwork` pods).
