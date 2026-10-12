# cs-firewall-bouncer: references

## Sources

- Upstream: `github.com/crowdsecurity/cs-firewall-bouncer` at tag
  `v<BASE_VERSION>`; default config `config/crowdsec-firewall-bouncer.yaml`
- Docs: <https://docs.crowdsec.net/u/bouncers/firewall/>
- SELinux: `container.te` in `github.com/containers/container-selinux`

## Decisions

- **An application image, not part of a bootc image:** its own release
  cadence, rollback by tag, and the host image stays smaller.
  `bootc/build.sh` refuses it.
- **Sources from `ADD <git url>#v<BASE_VERSION>`, commit not pinned:**
  the binary runs as root with `NET_ADMIN` in the host network, so the
  build trusts upstream's tag anyway (buildah ignores `ADD --checksum`
  for git). A local podman build runs the host's `git`. The source has
  no `.git`: the build passes `BUILD_VERSION` and `BUILD_TAG` to the
  Makefile.
- **Smoke test `-T`:** prints the merged config, needs no netlink nor
  capability. Its `RUN` leaves empty `/dev`, `/proc`, `/sys` folders:
  harmless, the runtime mounts over them.
- **`label=disable`:** container-selinux grants
  `netlink_netfilter_socket` to the runtime's domain, not to
  `container_t`. It worked without on Fedora CoreOS (selinux-policy 42,
  enforcing); kept so the bouncer doesn't depend on the policy version.
- **Config at the upstream RPM's path,
  `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`:** upstream's
  docs apply, `.local` override included. One override file only:
  `scratch` has no shell for a `.d/` wrapper. Mounted without `:Z`: the
  container is unconfined, and relabeling a host `/etc` file is wrong.
- **`retry_initial_connect: true`:** otherwise the bouncer exits, and
  deletes its tables, when the first pull fails: a crash loop at boot or
  while a remote LAPI is down. Later errors are only logged and the bans
  stay.
- **Its own tables:** independent of firewalld (survives
  `firewall-cmd --reload`, nothing to open) and of almalinux's
  geo-blocking, which also drops (overlap is harmless).
