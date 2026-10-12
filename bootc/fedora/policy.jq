# Fails a bootc build when its policy.json is no longer the base image's
# plus our changes (bootc/REFERENCES.md, "Signing"), so that a change of the
# base's gets ported.
#
#   jq -e --slurpfile ours <our policy.json> -f policy.jq <base's policy.json>
#
# Ours is the base's with:
# - "default": reject, which bootc requires, and an explicit "" scope for
#   every transport, set to what the base's default gave it;
# - a requirement for our signature on ghcr.io/spnngl/images.
# Both sides are compared as effective policies: the default is folded into
# each transport's "" scope, then dropped. Formatting and key order don't
# matter. Fails with a message saying which part differs.

def effective($transports):
  .default as $default
  | reduce $transports[] as $t (.; .transports[$t][""] //= $default)
  | del(.default);

$ours[0] as $all
| ($all | del(.transports.docker["ghcr.io/spnngl/images"])) as $ours
| (($ours.transports + .transports) | keys) as $transports
| if $all.default != [{type: "reject"}] then
    error("our policy.json: default is not reject")
  elif $all.transports.docker["ghcr.io/spnngl/images"]
    != [{type: "sigstoreSigned", keyPath: "/usr/share/pki/containers/spnngl-images.pub"}] then
    error("our policy.json: ghcr.io/spnngl/images does not require our signature")
  elif effective($transports) != ($ours | effective($transports)) then
    error("our policy.json is not the base's plus our changes: port the base's change")
  else true
  end
