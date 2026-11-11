# Rules of the application images' resolved Bake definition
# (`docker buildx bake --print '*'` of every containers/ Bake file):
# matrix and functions applied, as CI builds it.
package containers.bake

import rego.v1

ghcr := "ghcr.io/spnngl/images/"

hub := "docker.io/loladelannoy/"

# tags() names every registry, ghcr.io first: each tag on ghcr.io, then
# the same on Docker Hub, in the same order. bake-build pushes and
# bake-push attests on the first.
deny contains msg if {
	some name, t in input.target
	count(t.tags) > 0
	not paired(t.tags)
	msg := sprintf("target %s: tags are not ghcr.io's then Docker Hub's, the same, in that order (containers/AGENTS.md, \"Versions\", tags(); .github/AGENTS.md, \"Rules\", registries)", [name])
}

paired(tags) if {
	count(tags) % 2 == 0
	half := floor(count(tags) / 2)
	every i in numbers.range(0, half - 1) {
		startswith(tags[i], ghcr)
		tags[i + half] == concat("", [hub, substring(tags[i], count(ghcr), -1)])
	}
}

# A tag pushed by two targets is overwritten by the last one built: one
# Debian release per image, one target per line.
deny contains msg if {
	some a, ta in input.target
	some b, tb in input.target
	a < b
	some tag in ta.tags
	tag in tb.tags
	msg := sprintf("targets %s and %s both push %s (containers/AGENTS.md, \"Versions\", debian)", [a, b, tag])
}

# build-apps.yml reads that one output option; any other is dropped.
deny contains msg if {
	some name, t in input.target
	some o in t.output
	o != {"type": "image", "rewrite-timestamp": "false"}
	msg := sprintf("target %s: output %v is not type=image,rewrite-timestamp=false (containers/AGENTS.md, \"Rules\", File times)", [name, o])
}

# setup-buildx's builder permits these two alone (bake-build's `allow`).
deny contains msg if {
	some name, t in input.target
	some e in t.entitlements
	not e in {"security.insecure", "network.host"}
	msg := sprintf("target %s: entitlement %s is not one setup-buildx's builder permits (containers/AGENTS.md, \"Rules\", Entitlements)", [name, e])
}
