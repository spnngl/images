package containers.bake_test

import data.containers.bake
import rego.v1

ok := {"target": {
	"app": {"tags": [
		"ghcr.io/spnngl/images/app:1.2.3",
		"ghcr.io/spnngl/images/app:1.2",
		"docker.io/loladelannoy/app:1.2.3",
		"docker.io/loladelannoy/app:1.2",
	]},
	"gentoo": {
		"tags": ["ghcr.io/spnngl/images/gentoo:x", "docker.io/loladelannoy/gentoo:x"],
		"output": [{"type": "image", "rewrite-timestamp": "false"}],
		"entitlements": ["security.insecure"],
	},
	"app-reports": {},
}}

with_target(t) := object.union(ok, {"target": {"bad": t}})

test_ok if {
	count(bake.deny) == 0 with input as ok
}

test_tags_order if {
	bake.deny[concat("", ["target bad: tags are not ghcr.io's then Docker Hub's, the same, in that order ", msg_tags])] with input as with_target({"tags": [
		"ghcr.io/spnngl/images/bad:1",
		"docker.io/loladelannoy/bad:1",
		"ghcr.io/spnngl/images/bad:2",
		"docker.io/loladelannoy/bad:2",
	]})
}

test_tags_hub_missing if {
	bake.deny[concat("", ["target bad: tags are not ghcr.io's then Docker Hub's, the same, in that order ", msg_tags])] with input as with_target({"tags": ["ghcr.io/spnngl/images/bad:1"]})
}

test_tags_other_registry if {
	bake.deny[concat("", ["target bad: tags are not ghcr.io's then Docker Hub's, the same, in that order ", msg_tags])] with input as with_target({"tags": ["quay.io/x/bad:1", "docker.io/loladelannoy/bad:1"]})
}

msg_tags := "(containers/AGENTS.md, \"Versions\", tags(); .github/AGENTS.md, \"Rules\", registries)"

test_tag_in_two_targets if {
	bake.deny["targets app and bad both push ghcr.io/spnngl/images/app:1.2 (containers/AGENTS.md, \"Versions\", debian)"] with input as with_target({"tags": ["ghcr.io/spnngl/images/app:1.2", "docker.io/loladelannoy/app:1.2"]})
}

test_output if {
	bake.deny["target bad: output {\"type\": \"image\"} is not type=image,rewrite-timestamp=false (containers/AGENTS.md, \"Rules\", File times)"] with input as with_target({"output": [{"type": "image"}]})
}

test_entitlement if {
	bake.deny["target bad: entitlement network.none is not one setup-buildx's builder permits (containers/AGENTS.md, \"Rules\", Entitlements)"] with input as with_target({"entitlements": ["network.none"]})
}
