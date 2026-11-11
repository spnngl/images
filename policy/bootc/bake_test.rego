package bootc.bake_test

import data.bootc.bake
import rego.v1

source := {"org.opencontainers.image.source": "https://github.com/spnngl/images"}

ok := {"target": {
	"fedora-45": {"tags": ["ghcr.io/spnngl/images/fedora:45-v1.37k3s"], "args": {"BASE_VERSION": "45"}, "labels": source},
	"fedora-coreos-1-37-reports": {"args": {}, "labels": source},
	"bootc": {"labels": source},
}}

with_target(t) := object.union(ok, {"target": {"bad": t}})

test_ok if {
	count(bake.deny) == 0 with input as ok
}

test_other_registry if {
	bake.deny["target bad: tag docker.io/loladelannoy/bad:1 is not in ghcr.io/spnngl/images/ (bootc/docker-bake.hcl, tags())"] with input as with_target({"tags": ["docker.io/loladelannoy/bad:1"], "args": {"BASE_VERSION": "1"}, "labels": source})
}

test_tag_in_two_targets if {
	bake.deny["targets bad and fedora-45 both push ghcr.io/spnngl/images/fedora:45-v1.37k3s (bootc/docker-bake.hcl, tags())"] with input as with_target({"tags": ["ghcr.io/spnngl/images/fedora:45-v1.37k3s"], "args": {"BASE_VERSION": "45"}, "labels": source})
}

test_no_base_version if {
	bake.deny["target bad: no args.BASE_VERSION (bootc/AGENTS.md, \"Rules\")"] with input as with_target({"tags": ["ghcr.io/spnngl/images/bad:1"], "args": {}, "labels": source})
}

test_no_source if {
	bake.deny["target bad: no label org.opencontainers.image.source (bootc/docker-bake.hcl, target \"bootc\")"] with input as with_target({"tags": ["ghcr.io/spnngl/images/bad:1"], "args": {"BASE_VERSION": "1"}})
}

test_empty_base_version if {
	bake.deny["target bad: no args.BASE_VERSION (bootc/AGENTS.md, \"Rules\")"] with input as with_target({"tags": ["ghcr.io/spnngl/images/bad:1"], "args": {"BASE_VERSION": ""}, "labels": source})
}
