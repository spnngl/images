package containers.containerfile_test

import data.containers.containerfile
import rego.v1

c(cmd, value, json, stage) := {"Cmd": cmd, "Flags": [], "Value": value, "JSON": json, "Stage": stage}

from(image, stage) := c("from", [image], false, stage)

# A build stage, then the image's stage, as most Containerfiles are.
ok := [
	c("arg", ["BASE_VERSION"], false, 0),
	c("from", ["docker.io/library/golang:1@sha256:00", "AS", "build"], false, 0),
	c("arg", ["BASE_CHECKSUM"], false, 0),
	c("comment", ["a comment"], false, 0),
	from("scratch", 1),
	c("copy", ["/out", "/usr/bin/app"], false, 1),
	c("entrypoint", ["/usr/bin/app"], true, 1),
	c("cmd", ["--flag"], true, 1),
	c("healthcheck", ["CMD", "/usr/bin/app", "health"], true, 1),
]

test_ok if {
	count(containerfile.deny) == 0 with input as ok
}

test_from_without_digest if {
	containerfile.deny["FROM docker.io/library/golang:1 has no digest (containers/AGENTS.md, \"Rules\", FROM digests)"] with input as array.concat(ok, [from("docker.io/library/golang:1", 2)])
}

test_from_stage_or_scratch if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [from("build", 2), c("entrypoint", ["/x"], true, 2)])
}

test_version_default if {
	containerfile.deny["ARG BASE_VERSION has a default (containers/AGENTS.md, \"Versions\")"] with input as array.concat([c("arg", ["BASE_VERSION=1"], false, 0)], ok)
}

test_checksum_default if {
	containerfile.deny["ARG BASE_CHECKSUM has a default (containers/AGENTS.md, \"Versions\")"] with input as array.concat(ok, [c("arg", ["BASE_CHECKSUM=abc"], false, 1)])
}

test_other_default if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [c("arg", ["TARGETARCH=amd64"], false, 1)])
}

test_entrypoint_shell_form if {
	containerfile.deny["ENTRYPOINT /usr/bin/app run is shell form (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as array.concat(ok, [c("entrypoint", ["/usr/bin/app run"], false, 1)])
}

test_cmd_shell_form if {
	containerfile.deny["CMD app run is shell form (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as array.concat(ok, [c("cmd", ["app run"], false, 1)])
}

test_entrypoint_relative if {
	containerfile.deny["ENTRYPOINT app is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as array.concat(ok, [c("entrypoint", ["app"], true, 1)])
}

test_entrypoint_empty if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [c("entrypoint", [], true, 1)])
}

test_healthcheck_shell_form if {
	containerfile.deny["HEALTHCHECK CMD /usr/bin/app health is not exec form with an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as array.concat(ok, [c("healthcheck", ["CMD", "/usr/bin/app health"], false, 1)])
}

test_healthcheck_relative if {
	containerfile.deny["HEALTHCHECK CMD app is not exec form with an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as array.concat(ok, [c("healthcheck", ["CMD", "app"], true, 1)])
}

test_healthcheck_none if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [c("healthcheck", ["NONE"], false, 1)])
}

test_last_stage_run if {
	containerfile.deny["RUN /usr/bin/app --version in the image's stages has no --mount: a structure test (containers/AGENTS.md, \"Rules\", Tests)"] with input as array.concat(ok, [c("run", ["/usr/bin/app", "--version"], true, 1)])
}

test_last_stage_run_mount if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [object.union(c("run", ["/usr/bin/app", "/tmp/x"], true, 1), {"Flags": ["--mount=type=tmpfs,target=/tmp"]})])
}

test_build_stage_run if {
	count(containerfile.deny) == 0 with input as array.concat(
		[from("scratch", 0), c("run", ["make"], false, 0)],
		array.slice(ok, 4, count(ok)),
	)
}

# A build stage's instructions are not the image's.
test_build_stage_shell_form if {
	count(containerfile.deny) == 0 with input as array.concat(
		[from("scratch", 0), c("entrypoint", ["app run"], false, 0)],
		[from("scratch", 1), c("entrypoint", ["/app"], true, 1)],
	)
}

# A last stage FROM an earlier one inherits its entrypoint (rapx).
test_inherited_stage if {
	containerfile.deny["ENTRYPOINT app is not an absolute path (containers/AGENTS.md, \"Rules\", Shell-less)"] with input as [
		c("from", ["scratch", "AS", "image"], false, 0),
		c("entrypoint", ["app"], true, 0),
		from("image", 1),
		c("run", ["/app", "--version"], true, 1),
	]
}

test_from_short_name if {
	containerfile.deny["FROM alpine:3 has no digest (containers/AGENTS.md, \"Rules\", FROM digests)"] with input as array.concat(ok, [from("alpine:3", 2)])
}

test_version_default_second_name if {
	containerfile.deny["ARG B_VERSION has a default (containers/AGENTS.md, \"Versions\")"] with input as array.concat(ok, [c("arg", ["A", "B_VERSION=1"], false, 1)])
}

test_from_stage_from_arg if {
	count(containerfile.deny) == 0 with input as array.concat(ok, [from("natives-${TARGETARCH}", 2), c("entrypoint", ["/x"], true, 2)])
}

test_parent_stage_run if {
	containerfile.deny["RUN /bin/x in the image's stages has no --mount: a structure test (containers/AGENTS.md, \"Rules\", Tests)"] with input as array.concat(ok, [
		c("from", ["scratch", "AS", "base"], false, 2),
		c("run", ["/bin/x"], true, 2),
		from("base", 3),
		c("entrypoint", ["/x"], true, 3),
	])
}
