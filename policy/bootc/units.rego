# fedora-coreos's platform layers (`--parser ini`): a unit, drop-in or
# .network file of sysroot/vm/ runs in VMs only, one of sysroot/metal/
# on bare metal only (bootc/fedora-coreos/AGENTS.md, "One image for VMs
# and dedicated servers"). The `*.wants/` links are not passed: they
# enable the units checked here.
package bootc.units

import rego.v1

# The file's folder, absolute (conftest's data.conftest.file).
dir := concat("", [data.conftest.file.dir, "/"])

deny contains msg if {
	contains(dir, "/sysroot/vm/")
	not vm
	msg := "has no ConditionVirtualization=vm ([Match] Virtualization=vm for a .network) (bootc/fedora-coreos/AGENTS.md, \"Rules\", One image for VMs and dedicated servers)"
}

deny contains msg if {
	contains(dir, "/sysroot/metal/")
	not metal
	msg := "has no ConditionVirtualization=false ([Match] Virtualization=false for a .network) (bootc/fedora-coreos/AGENTS.md, \"Rules\", One image for VMs and dedicated servers)"
}

vm if input.Unit.ConditionVirtualization == "vm"

vm if input.Match.Virtualization == "vm"

# The ini parser reads a `false` value as the boolean.
metal if input.Unit.ConditionVirtualization in {false, "false"}

metal if input.Match.Virtualization in {false, "false"}
