# git

Git, the client, built from source: static musl binaries (git, its
helpers, OpenSSH's `ssh`) on this repository's busybox image, whose
shell runs git's hooks, aliases and script commands. For CI jobs, init
containers and Kubernetes jobs that clone, fetch or push. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Build stage on Alpine, not Debian:** Debian has no static libcurl.
  Alpine's packages are not pinned: its release branch keeps only the
  newest build of each; the `FROM` digest pins the branch.
- **Every program static:** the build stage fails on an ELF file in the
  image with an interpreter or a `NEEDED` library; busybox's image has no
  C library. A new library comes from an Alpine `*-static` package.
- **Meson features are `enabled` or `disabled`, not `auto`:** a
  missing package fails the build instead of dropping the feature. Perl
  and Python stay off: the image has no interpreter.
- **Builds run in `/build`, copies of the sources:** cargo writes git's
  `Cargo.lock`, autoreconf and configure write into OpenSSH's tree, and
  `ADD` makes the sources root's.
- **OpenSSH: `--without-pie`:** with configure's `-pie`, `ssh` links
  dynamically and only the final stage notices.
- **Done when** the build passes: the build stage checks that every
  program is static, pushes and clones over ssh (OpenSSH's `sshd`) and
  clones over HTTPS (`openssl s_server`, failing without its
  certificate); the final stage runs `git`, `ssh` and `git init`.

## Updates

git and OpenSSH automerge when the build passes: the smoke test covers
the build and both transports. A checksum-only update means upstream
moved the tag. Alpine: Renovate moves the digest; a new branch (3.25)
may rename a package, the build fails on it. The busybox base follows
`containers/busybox`'s releases.
