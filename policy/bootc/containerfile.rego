# Rules of every bootc/*/Containerfile (bootc/AGENTS.md).
package bootc.containerfile

import data.lib.dockerfile
import rego.v1

cmds := dockerfile.instructions(input)

# A bootc base follows its tag (renovate.json5 ignores the digest
# pinning presets): the weekly rebuild takes the base's fixes.
deny contains msg if {
	some c in cmds
	c.Cmd == "from"
	contains(c.Value[0], "@")
	msg := sprintf("FROM %s has a digest (renovate.json5, ignorePresets)", [c.Value[0]])
}

# BASE_VERSION, before the first FROM, picks the base release; Bake sets
# it, so it has no default.
deny contains "no ARG BASE_VERSION before the first FROM (bootc/AGENTS.md, \"Rules\")" if {
	not base_version_global
}

base_version_global if {
	some c in dockerfile.global(cmds)
	c.Cmd == "arg"
	"BASE_VERSION" in dockerfile.arg_names(c)
}

deny contains msg if {
	some c in cmds
	c.Cmd == "arg"
	some name in dockerfile.arg_defaults(c)
	endswith(name, "_VERSION")
	msg := sprintf("ARG %s has a default (bootc/AGENTS.md, \"Rules\")", [name])
}

# The image's stage ends with the lint: it checks the tree as shipped.
deny contains "the image's stage does not end with RUN bootc container lint (bootc/AGENTS.md, \"Rules\")" if {
	s := dockerfile.stage(cmds, dockerfile.image_stage(cmds))
	not lint(s[count(s) - 1])
}

lint(c) if {
	c.Cmd == "run"
	c.Value == ["bootc container lint"]
}
