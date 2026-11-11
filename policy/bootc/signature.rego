# The hosts' signature chain, across files (`--combine`: `input` is a
# list of {path, contents}): every bootc/*/sysroot/ policy.json and
# registries.d file. A scope one host verifies, every host verifies
# (.github/AGENTS.md, "Rules", a new registry).
package bootc.signature

import rego.v1

key := "/usr/share/pki/containers/spnngl-images.pub"

policies := [f | some f in input; endswith(f.path, "/policy.json")]

registries := [f | some f in input; contains(f.path, "/registries.d/")]

signs(policy, scope) if {
	some r in policy.contents.transports.docker[scope]
	r.type == "sigstoreSigned"
	r.keyPath == key
}

# The scopes some policy.json verifies with our key.
scopes contains scope if {
	some p in policies
	some scope, _ in p.contents.transports.docker
	signs(p, scope)
}

deny contains msg if {
	some scope in scopes
	some p in policies
	not signs(p, scope)
	msg := sprintf("%s: %s is not sigstoreSigned with %s (.github/AGENTS.md, \"Rules\", registries)", [p.path, scope, key])
}

# Without use-sigstore-attachments, bootc and podman find no signature.
deny contains msg if {
	some scope in scopes
	some r in registries
	not r.contents.docker[scope]["use-sigstore-attachments"] == true
	msg := sprintf("%s: %s has no use-sigstore-attachments: true (.github/AGENTS.md, \"Rules\", registries)", [r.path, scope])
}

deny contains "no registries.d file (.github/AGENTS.md, \"Rules\", registries)" if {
	count(scopes) > 0
	count(registries) == 0
}
