package bootc.units_test

import data.bootc.units
import rego.v1

vm := {"dir": "/w/bootc/fedora-coreos/sysroot/vm/usr/lib/systemd/system", "name": "a.service"}

metal := {"dir": "/w/bootc/fedora-coreos/sysroot/metal/usr/lib/systemd/system", "name": "a.service"}

msg_vm := "has no ConditionVirtualization=vm ([Match] Virtualization=vm for a .network) (bootc/fedora-coreos/AGENTS.md, \"Rules\", One image for VMs and dedicated servers)"

msg_metal := "has no ConditionVirtualization=false ([Match] Virtualization=false for a .network) (bootc/fedora-coreos/AGENTS.md, \"Rules\", One image for VMs and dedicated servers)"

test_vm_unit if {
	count(units.deny) == 0 with input as {"Unit": {"ConditionVirtualization": "vm"}} with data.conftest.file as vm
}

test_vm_network if {
	count(units.deny) == 0 with input as {"Match": {"Virtualization": "vm"}} with data.conftest.file as vm
}

test_vm_missing if {
	units.deny[msg_vm] with input as {"Unit": {"Description": "x"}} with data.conftest.file as vm
}

test_vm_unit_on_metal if {
	units.deny[msg_vm] with input as {"Unit": {"ConditionVirtualization": "false"}} with data.conftest.file as vm
}

test_metal_unit if {
	count(units.deny) == 0 with input as {"Unit": {"ConditionVirtualization": false}} with data.conftest.file as metal
}

test_metal_missing if {
	units.deny[msg_metal] with input as {"Unit": {"ConditionCPUs": ">=64"}} with data.conftest.file as metal
}

test_metal_network if {
	count(units.deny) == 0 with input as {"Match": {"Virtualization": false}} with data.conftest.file as metal
}
