package bootc.signature_test

import data.bootc.signature
import rego.v1

signed := [{"type": "sigstoreSigned", "keyPath": "/usr/share/pki/containers/spnngl-images.pub"}]

any := [{"type": "insecureAcceptAnything"}]

policy(path, docker) := {"path": path, "contents": {"transports": {"docker": docker}}}

attachments := {"path": "a/registries.d/spnngl-images.yaml", "contents": {"docker": {"ghcr.io/spnngl/images": {"use-sigstore-attachments": true}}}}

ok := [
	policy("a/policy.json", {"ghcr.io/spnngl/images": signed, "": any}),
	policy("b/policy.json", {"ghcr.io/spnngl/images": signed, "registry.redhat.io": any}),
	attachments,
]

test_ok if {
	count(signature.deny) == 0 with input as ok
}

test_scope_unsigned_elsewhere if {
	signature.deny["b/policy.json: quay.io/spnngl is not sigstoreSigned with /usr/share/pki/containers/spnngl-images.pub (.github/AGENTS.md, \"Rules\", registries)"] with input as array.concat(ok, [
		policy("c/policy.json", {"ghcr.io/spnngl/images": signed, "quay.io/spnngl": signed}),
		{"path": "a/registries.d/quay.yaml", "contents": {"docker": {"quay.io/spnngl": {"use-sigstore-attachments": true}}}},
	])
}

test_no_attachments if {
	signature.deny["a/registries.d/spnngl-images.yaml: ghcr.io/spnngl/images has no use-sigstore-attachments: true (.github/AGENTS.md, \"Rules\", registries)"] with input as array.concat(array.slice(ok, 0, 2), [{"path": "a/registries.d/spnngl-images.yaml", "contents": {"docker": {}}}])
}

test_no_registries_file if {
	signature.deny["no registries.d file (.github/AGENTS.md, \"Rules\", registries)"] with input as array.slice(ok, 0, 2)
}
