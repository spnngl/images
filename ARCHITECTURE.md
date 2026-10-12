# Architecture

Two kinds of OCI image, built by CI and pushed, signed, to
`ghcr.io/spnngl/images/<name>:<BASE_VERSION>` (application images:
`<name>:<BASE_VERSION>-debian<N>`):

- **bootc images** (`bootc/`): bootable operating systems. A host boots
  from one and updates by pulling a newer one (`bootc upgrade`). Built
  with podman; `bootc/build.sh` also turns one into a qcow2 disk image
  for the first install, with image-builder.
- **Application images** (`containers/`): upstream apps the hosts run,
  shell-less, from a Containerfile on `scratch`, a Dalec spec, or a DHI
  definition. Built with `docker buildx`.

The two share no build input: different builders, workflows and rules.

## Lifecycle

1. **Pin:** Renovate tracks every version (base image, upstream
   release, checksum; application images: in `docker-bake.hcl`) and
   proposes bumps on Saturdays.
2. **Build:** on a change, CI builds each platform natively, runs the
   image's tests, and pushes one manifest list per image.
3. **Rebuild:** every Sunday, so images pick up base and package fixes
   under the same tag.
4. **Verify:** CI signs each pushed image with one cosign key; bootc
   hosts refuse an unsigned one (`policy.json`). Scanners check images
   on pull requests and daily.
5. **Upgrade:** a host follows its tag (`bootc upgrade`); a new tag (a
   base major release, a Kubernetes minor release) needs `bootc switch`.

## Layout

```
.
├── .agents/skills/             # add-*-image: recipes for a new application image
├── .github/                    # CI workflows; AGENTS.md, REFERENCES.md
├── .hadolint.yaml              # hadolint config for every Containerfile
├── .shellcheckrc               # shellcheck config for every script
├── .grype.yaml                 # vulnerability false positives, Grype
├── .trivyignore.yaml           # vulnerability false positives, Trivy
├── AGENTS.md                   # agent rules for every image
├── cosign.pub                  # signing public key, a symlink into bootc/fedora/
├── renovate.json5              # what Renovate tracks, and how
├── bootc/                      # shared build context of every bootc image
│   ├── AGENTS.md, REFERENCES.md
│   ├── K3S.md                  # setting up k3s hosts
│   ├── build.sh [name]         # container image, then output/<name>/<name>.qcow2
│   ├── run.sh [name]           # boot the qcow2 in QEMU (macOS Apple Silicon)
│   ├── config.example.toml     # template for ./config.toml (git-ignored)
│   ├── k3s/                    # shared by every kubeenv stage (not an image)
│   └── <name>/                 # one bootc image
│       ├── AGENTS.md, REFERENCES.md
│       ├── Containerfile
│       └── sysroot/            # files at their path in the image:
│                               # common/, then <BASE_VERSION>/
├── containers/                 # application images
│   ├── AGENTS.md
│   ├── docker-bake.hcl         # shared: Debian releases, snapshot, tag functions
│   └── <name>/                 # one image, and its build context
│       ├── AGENTS.md, REFERENCES.md
│       ├── docker-bake.hcl     # its versions, checksums and tags
│       ├── .dockerignore
│       ├── Containerfile       # or spec.yml (Dalec), or dhi.yaml (DHI)
│       └── sysroot/            # files copied as is, if any
└── output/                     # build results (git-ignored)
```
