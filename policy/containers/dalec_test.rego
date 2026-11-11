package containers.dalec_test

import data.containers.dalec
import rego.v1

ok := {
	"args": {"BASE_VERSION": "", "BASE_CHECKSUM": "", "NODE_IMAGE": "node"},
	"image": {"entrypoint": "/usr/bin/app --foreground"},
}

test_ok if {
	count(dalec.deny) == 0 with input as ok
}

test_version_default if {
	dalec.deny["args.BASE_VERSION has a default (containers/AGENTS.md, \"Versions\")"] with input as object.union(ok, {"args": {"BASE_VERSION": "1"}})
}

test_checksum_default if {
	dalec.deny["args.PAR2_CHECKSUM has a default (containers/AGENTS.md, \"Versions\")"] with input as object.union(ok, {"args": {"PAR2_CHECKSUM": "abc"}})
}

test_entrypoint_relative if {
	dalec.deny["image.entrypoint app is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as object.union(ok, {"image": {"entrypoint": "app --foreground"}})
}

test_version_null if {
	count(dalec.deny) == 0 with input as object.union(ok, {"args": {"BASE_VERSION": null}})
}

test_target_entrypoint_relative if {
	dalec.deny["image.entrypoint app is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as object.union(ok, {"targets": {"trixie": {"image": {"entrypoint": "app"}}}})
}
