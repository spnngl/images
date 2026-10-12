# bootc images: references

## Sources

- bootc: `github.com/bootc-dev/bootc` (`docs/src`, lint rules in
  `crates/lib/src/lints.rs`); <https://bootc.dev/bootc/>
- Fedora bootc examples: `gitlab.com/fedora/bootc/examples`
- image-builder: `github.com/osbuild/image-builder`
  (bootc-image-builder lives in `bootc-image-builder/` there; build
  config: its `README.md#-build-config`); blueprint reference:
  <https://osbuild.org/docs/user-guide/blueprint-reference/> (each
  option's bootc tab)
- buildah, which runs the Containerfiles: `github.com/containers/buildah`
- firewalld: `github.com/firewalld/firewalld` (`doc/xml` for docs,
  `src/firewall/core` for behaviour)
- containers/image signature policy: `github.com/containers/container-libs`
  (`image/signature/`)
- Base image tags: each image's `REFERENCES.md`

## Decisions

- **Shared build context `bootc/`:** `build.sh` passes `-f
  bootc/<name>/Containerfile` with context `bootc/`, so almalinux and
  centos reuse `fedora/sysroot/common/` instead of duplicating it. One
  `.containerignore` per context is enough: buildah reads it only from
  the context root (or `--ignorefile`).
- **`sysroot/<BASE_VERSION>/` after `sysroot/common/`:** almalinux
  builds 9 and 10 from one Containerfile, and a base upgrade adds a
  folder instead of editing the one the running release uses.
- **Content in `/usr`, `/var` empty:** deployed, `/usr` is read-only and
  replaced on every update, `/etc` merged three ways, and `/var` copied
  from the image only at the first install: anything left there never
  updates.
- **`COPY` after the package install:** editing a config file doesn't
  rerun dnf. **`COPY`, not `ADD`**, which also downloads and unpacks;
  except almalinux's build-only `geoblock` stage, for `ADD <url>`'s
  content-digest cache.
- **Base pinned to a major release:** `latest` would jump releases
  without warning. Hosts on `<name>:<BASE_VERSION>` get every rebuild
  through `bootc upgrade` and change release only with `bootc switch`.
- **`bootc container lint` without `--fatal-warnings`:** errors fail
  the build, warnings are printed.
- **hadolint ignores DL3041** (pin dnf versions): packages follow the
  pinned base release.
- **One `RUN <<EORUN` heredoc with `set -xeuo pipefail`:** one layer
  without `&& \` chains; a heredoc `RUN` only fails on its last command's
  status without `-e`. Needs buildah 1.33+.

## Firewalld

- **`--remove-service-from-zone=<service>`** is `firewall-offline-cmd`'s
  zone-scoped removal. `--remove-service` is a legacy "lokkit" option,
  exclusive with others ("Can't use lokkit options with other options");
  `--delete-service` deletes the global definition, which fails for
  built-in services (`BUILTIN_SERVICE`) such as `ssh` or `cockpit`. For
  a policy: `--remove-service-from-policy`.
- **`--check-config` validates zone, policy and ipset wiring, not ipset
  entries:** a missing ipset fails (`INVALID_IPSET`), an invalid address
  is silently ignored, overlapping or empty ipsets pass. Ipsets built from
  external data validate themselves (`bootc/almalinux/geoblock.nu`).

## Signing

CI signs every image it pushes with a cosign key pair; hosts refuse
`ghcr.io/spnngl/images/*` without that signature. Local builds aren't
signed: a host installed from one upgrades from CI's signed images.

- **Keys:** the private key is the `COSIGN_PRIVATE_KEY` repository
  secret, without passphrase (with one, add a secret and write it to
  `--sign-passphrase-file`). The public key is
  `bootc/fedora/sysroot/common/usr/share/pki/containers/spnngl-images.pub`,
  in `/usr` to update with the image.
- **`podman push --sign-by-sigstore-private-key`, not `cosign sign`:**
  bootc verifies through containers/image, which reads sigstore
  signatures only as `sha256-<digest>.sig` attachments; cosign 3 stores
  a bundle behind OCI referrers by default. podman writes attachments
  from cosign keys. No Rekor entry; the policy asks for none.
  Application images use `cosign sign` with cosign 3's legacy flags,
  which write the same attachments (`build-apps.yml` explains each);
  `--sign-container-identity` claims the tag, as podman does, or a tag
  pull is rejected.
- **Not keyless:** the policy matches a Fulcio certificate by email only
  (`subjectEmail`, `image/signature/fulcio_cert.go`), and a GitHub
  Actions certificate carries the workflow's URL.
- **`etc/containers/registries.d/spnngl-images.yaml`** turns on
  `use-sigstore-attachments` for our namespace: to read signatures on
  hosts and write them in CI.
- **`etc/containers/policy.json`, one per image and base release**
  (`sysroot/<BASE_VERSION>/`; AlmaLinux 9 uses GPG keys for Red Hat's
  registries, 10 sigstore): the base's file plus `"default": reject` and
  a `sigstoreSigned` requirement for `ghcr.io/spnngl/images`. It
  replaces containers-common's (in `/etc`, or `/usr/share/containers`
  on CentOS Stream 10), since `policy.json` has no drop-in folder.
  `bootc/fedora/policy.jq` checks ours is still the base's plus those
  changes and fails the build otherwise: a new base release, or a
  change within one at the weekly rebuild.
- **`"default": reject`:** required by `enforce-container-sigpolicy =
  true` (`usr/lib/bootc/install/50-rootfs.toml`). Every other transport
  and registry still accepts anything (`containers-storage` is how
  image-builder installs a local build).
- **Rotating the key:** ship the new public key next to the old one
  (`keyPaths`), let hosts upgrade, switch the CI secret, then run both
  build workflows by hand: a push only re-signs what it rebuilds.
- **bootc build provenance on top:** `actions/attest-build-provenance`, a
  bundle behind OCI referrers that hosts don't read. Check it with `gh
  attestation verify oci://ghcr.io/spnngl/images/<name>:<tag> -R
  spnngl/images`. The action reads only Docker's credential file, so CI
  logs podman in with `REGISTRY_AUTH_FILE=~/.docker/config.json`.

## Disk images: `build.sh`

`bootc/build.sh` runs a pinned `ghcr.io/osbuild/image-builder-cli`:

- **`--privileged --security-opt label=type:unconfined_t`:** it
  relabels files and sets up loop devices; confined, it fails with
  `chcon: ... Permission denied`.
- **`-v /var/lib/containers/storage:/var/lib/containers/storage`:** it
  reads the image from the host's rootful storage; without the mount it
  pulls the tag from ghcr.io instead of the local build.
- **Rootful podman**, which it checks for. On macOS: `podman machine set
  --rootful`, no `sudo`.
- **`--blueprint /config.toml`:** users and SSH keys go into the disk
  image only. It holds credentials: git-ignored, template
  `bootc/config.example.toml`.
- **`--output-dir <name> --output-name <name>`:** a fixed path,
  `output/<name>/<name>.qcow2`.
- Tag `ghcr.io/spnngl/images/<name>:<BASE_VERSION>`, CI's for the
  default target, so an installed host upgrades from CI's images.
  Default target only, never pushed.

## Running: `run.sh`

QEMU with HVF, the `virt` machine and Homebrew's aarch64 UEFI firmware.
Serial console in the terminal (`Ctrl-a x` quits); SSH forwarded from
`localhost:${SSH_PORT:-2222}` to the guest's sshd on 42022.
`-snapshot` drops disk changes on exit.

## Known limits

- `run.sh` only supports macOS on Apple Silicon.
- Only qcow2 is built: other formats change the image type in
  `build.sh` (`anaconda-iso`, `raw`, `vmdk`).
- `build.sh` builds for the host architecture only. x86_64 on an arm
  Mac needs `podman build --platform linux/amd64` and image-builder's
  target architecture option: experimental, emulated, slow.
