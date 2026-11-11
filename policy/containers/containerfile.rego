# Rules of every containers/*/Containerfile (containers/AGENTS.md).
package containers.containerfile

import data.lib.dockerfile
import rego.v1

cmds := dockerfile.instructions(input)

# A registry image is pinned by digest: Renovate's dockerfile manager
# updates it. Not an earlier stage, nor `scratch`, nor a stage name made
# from an ARG (mjolnir's `natives-${TARGETARCH}`: no `/`).
deny contains msg if {
	some c in cmds
	c.Cmd == "from"
	image := c.Value[0]
	not lower(image) in object.keys(dockerfile.aliases(cmds))
	lower(image) != "scratch"
	not stage_from_arg(image)
	not contains(image, "@")
	msg := sprintf("FROM %s has no digest (containers/AGENTS.md, \"Rules\", FROM digests)", [image])
}

# Versions come from Bake alone: a build without it fails, never builds a
# stale version.
deny contains msg if {
	some c in cmds
	c.Cmd == "arg"
	some name in dockerfile.arg_defaults(c)
	versioned(name)
	msg := sprintf("ARG %s has a default (containers/AGENTS.md, \"Versions\")", [name])
}

stage_from_arg(image) if {
	contains(image, "$")
	not contains(image, "/")
}

versioned(name) if endswith(name, "_VERSION")

versioned(name) if endswith(name, "_CHECKSUM")

# What the image runs is exec form, the program by absolute path: the
# image has no shell to find it. CMD may be the entrypoint's arguments,
# so only its form is checked.
deny contains msg if {
	some c in image_cmds
	c.Cmd in {"entrypoint", "cmd"}
	not c.JSON
	msg := sprintf("%s %s is shell form (containers/AGENTS.md, \"Rules\", Shell-less)", [upper(c.Cmd), concat(" ", c.Value)])
}

deny contains msg if {
	some c in image_cmds
	c.Cmd == "entrypoint"
	c.JSON
	count(c.Value) > 0
	not startswith(c.Value[0], "/")
	msg := sprintf("ENTRYPOINT %s is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)", [c.Value[0]])
}

# HEALTHCHECK CMD's Value is ["CMD", <program>, ...]; HEALTHCHECK NONE
# runs nothing.
deny contains msg if {
	some c in image_cmds
	c.Cmd == "healthcheck"
	upper(c.Value[0]) == "CMD"
	not healthcheck_ok(c)
	msg := sprintf("HEALTHCHECK %s is not exec form with an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)", [concat(" ", c.Value)])
}

healthcheck_ok(c) if {
	c.JSON
	startswith(c.Value[1], "/")
}

# A command of the shipped image is a structure test, not a RUN of the
# last stage or of a stage it is built FROM; one with --mount stays: it
# reads a build stage's file, or needs a tmpfs.
deny contains msg if {
	some c in image_cmds
	c.Cmd == "run"
	not mounts(c)
	msg := sprintf("RUN %s in the image's stages has no --mount: a structure test (containers/AGENTS.md, \"Rules\", Tests)", [concat(" ", c.Value)])
}

mounts(c) if {
	some f in c.Flags
	startswith(f, "--mount=")
}

image_cmds := [c |
	some c in cmds
	c.Stage in dockerfile.image_chain(cmds)
]
