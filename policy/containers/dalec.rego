# Rules of every containers/*/spec.yml, a Dalec spec (containers/AGENTS.md).
package containers.dalec

import rego.v1

# Versions come from Bake alone: an empty default fails a build without
# it, never builds a stale version.
deny contains msg if {
	some name, value in input.args
	versioned(name)
	not value in {"", null}
	msg := sprintf("args.%s has a default (containers/AGENTS.md, \"Versions\")", [name])
}

versioned(name) if endswith(name, "_VERSION")

versioned(name) if endswith(name, "_CHECKSUM")

# Dalec's entrypoint is a string, split on spaces into exec form: its
# program needs an absolute path, the image has no shell to find it. A
# target's image settings override the spec's.
deny contains msg if {
	some image in array.concat([input.image], [t.image | some t in input.targets])
	program := split(image.entrypoint, " ")[0]
	not startswith(program, "/")
	msg := sprintf("image.entrypoint %s is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)", [program])
}
