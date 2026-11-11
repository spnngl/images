package bootc.containerfile_test

import data.bootc.containerfile
import rego.v1

c(cmd, value, stage) := {"Cmd": cmd, "Flags": [], "Value": value, "JSON": false, "Stage": stage}

lint(stage) := c("run", ["bootc container lint"], stage)

head := [
	c("arg", ["BASE_VERSION"], 0),
	c("from", ["quay.io/fedora/fedora-bootc:${BASE_VERSION}", "AS", "base"], 0),
	c("arg", ["SOURCE_DATE_EPOCH=0"], 0),
	c("from", ["base", "AS", "kubeenv"], 1),
	c("arg", ["INSTALL_K3S_VERSION"], 1),
	c("run", ["bash /k3s/install.sh"], 1),
]

ok := array.concat(head, [lint(1)])

test_ok if {
	count(containerfile.deny) == 0 with input as ok
}

test_digest if {
	containerfile.deny["FROM quay.io/fedora/fedora-bootc:45@sha256:00 has a digest (renovate.json5, ignorePresets)"] with input as array.concat(ok, [c("from", ["quay.io/fedora/fedora-bootc:45@sha256:00"], 2), lint(2)])
}

test_base_version_missing if {
	containerfile.deny["no ARG BASE_VERSION before the first FROM (bootc/AGENTS.md, \"Rules\")"] with input as array.slice(ok, 1, count(ok))
}

# The first stage's ARG BASE_VERSION is not the global one.
test_base_version_in_stage if {
	containerfile.deny["no ARG BASE_VERSION before the first FROM (bootc/AGENTS.md, \"Rules\")"] with input as array.concat(
		[ok[1], c("arg", ["BASE_VERSION"], 0)],
		array.slice(ok, 2, count(ok)),
	)
}

test_version_default if {
	containerfile.deny["ARG INSTALL_K3S_VERSION has a default (bootc/AGENTS.md, \"Rules\")"] with input as array.concat(
		array.slice(head, 0, 4),
		[c("arg", ["INSTALL_K3S_VERSION=v1"], 1), lint(1)],
	)
}

test_no_lint if {
	containerfile.deny["the image's stage does not end with RUN bootc container lint (bootc/AGENTS.md, \"Rules\")"] with input as head
}

# fedora-coreos: stages after the image, then a bare FROM of it.
test_bare_last_stage if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [
		c("from", ["kubeenv", "AS", "scan"], 2),
		c("run", ["oscap"], 2),
		c("from", ["kubeenv"], 3),
	])
}

test_bare_last_stage_no_lint if {
	containerfile.deny["the image's stage does not end with RUN bootc container lint (bootc/AGENTS.md, \"Rules\")"] with input as array.concat(head, [
		c("from", ["kubeenv", "AS", "scan"], 2),
		lint(2),
		c("from", ["kubeenv"], 3),
	])
}
