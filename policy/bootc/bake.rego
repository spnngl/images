# Rules of the bootc images' resolved Bake definition
# (`docker buildx bake --print '*'` of every bootc/ Bake file).
package bootc.bake

import rego.v1

ghcr := "ghcr.io/spnngl/images/"

# tags() (bootc/docker-bake.hcl) names ghcr.io alone: hosts pull and
# verify signatures there (policy.json).
deny contains msg if {
	some name, t in input.target
	some tag in t.tags
	not startswith(tag, ghcr)
	msg := sprintf("target %s: tag %s is not in %s (bootc/docker-bake.hcl, tags())", [name, tag, ghcr])
}

deny contains msg if {
	some a, ta in input.target
	some b, tb in input.target
	a < b
	some tag in ta.tags
	tag in tb.tags
	msg := sprintf("targets %s and %s both push %s (bootc/docker-bake.hcl, tags())", [a, b, tag])
}

# A pushed image names its base release (the tag, and the Containerfile's
# ARG without a default) and links its ghcr.io package to the repository.
deny contains msg if {
	some name, t in input.target
	count(t.tags) > 0
	object.get(t, ["args", "BASE_VERSION"], "") == ""
	msg := sprintf("target %s: no args.BASE_VERSION (bootc/AGENTS.md, \"Rules\")", [name])
}

deny contains msg if {
	some name, t in input.target
	count(t.tags) > 0
	object.get(t, ["labels", "org.opencontainers.image.source"], "") == ""
	msg := sprintf("target %s: no label org.opencontainers.image.source (bootc/docker-bake.hcl, target \"bootc\")", [name])
}
