# Policies

The rules of the `AGENTS.md` files that a file's text shows, written in
Rego and run by [conftest](https://www.conftest.dev/) on every source of
one kind of image. Reasons: `.github/REFERENCES.md`, "Policies".

```sh
policy/conftest.sh containers   # or bootc; --sarif <dir> also writes code scanning results
```

`conftest verify` runs first: every `*_test.rego`.

## Namespaces

One folder per kind, one file per input, its namespace from its path.

| Namespace | Input | Checks the rules of |
| --- | --- | --- |
| `containers.containerfile` | `containers/*/Containerfile` | `containers/AGENTS.md`: FROM digests, versions without a default, shell-less entrypoint, command and health check |
| `containers.dalec` | `containers/*/spec.yml` | `containers/AGENTS.md`: versions without a default, shell-less entrypoint |
| `containers.bake` | Bake's resolved definition | `containers/AGENTS.md`: `tags()`, one target per tag, `output`, entitlements |
| `bootc.containerfile` | `bootc/*/Containerfile` | `bootc/AGENTS.md`: `BASE_VERSION`, no digest, the lint last |
| `bootc.bake` | Bake's resolved definition | `bootc/docker-bake.hcl`: `tags()`, `BASE_VERSION`, source label |
| `bootc.signature` | every `policy.json` and `registries.d` file of `bootc/*/sysroot/`, as one input | `.github/AGENTS.md`: the registries' signature scopes |
| `bootc.units` | the units of `bootc/fedora-coreos/sysroot/{vm,metal}/` | `bootc/fedora-coreos/AGENTS.md`: one image for VMs and dedicated servers |

`lib/dockerfile.rego` reads a Containerfile's stages, for both kinds.

## Rules

- A rule enforces a rule written in an `AGENTS.md`, never a new one:
  write the rule there first.
- A `deny` message names what failed, then, in parentheses, the file
  and section of its rule.
- Each rule has a passing and a failing case in its `_test.rego`.
- A new input is a `check` line in `conftest.sh`, with its parser
  (`--parser`, `--combine`): a parser applies to a whole call.
- An exception goes in the policy, with its reason in a comment, never
  in the file checked.
