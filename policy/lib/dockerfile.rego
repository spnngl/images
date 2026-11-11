# Helpers over a Containerfile as conftest's dockerfile parser gives it
# (`--parser dockerfile`, parser/docker/docker.go): `conftest test`
# makes `input` the list of commands (`conftest parse` shows it wrapped
# in one more list), each `{Cmd, Flags, Value, JSON, Stage}`, `Cmd`
# lowercased, comments as `Cmd == "comment"`. An `ARG` before the first
# `FROM` has `Stage` 0, as the first stage's instructions do: positions
# tell them apart.
package lib.dockerfile

import rego.v1

# The instructions, in order, comments left out.
instructions(doc) := [c | some c in doc; c.Cmd != "comment"]

# Index in instructions(doc) of each stage's FROM, by stage.
from_index(cmds) := {c.Stage: i | some i, c in cmds; c.Cmd == "from"}

# The instructions before the first FROM (global ARGs).
global(cmds) := [c | some i, c in cmds; i < from_index(cmds)[0]]

# The instructions of stage s, its FROM first.
stage(cmds, s) := [c | some i, c in cmds; c.Stage == s; i >= from_index(cmds)[s]]

# The stage index of each stage named with `AS`, by lowercased name.
aliases(cmds) := {lower(c.Value[2]): c.Stage |
	some c in cmds
	c.Cmd == "from"
	count(c.Value) == 3
	upper(c.Value[1]) == "AS"
}

# The stage a stage is built FROM, when that is an earlier stage.
parent(cmds, s) := aliases(cmds)[lower(stage(cmds, s)[0].Value[0])]

last(cmds) := max(object.keys(from_index(cmds)))

# The stage of the image: the last one, or, when the last is a bare
# `FROM <stage>` (fedora-coreos's `image`, made the default), that stage.
image_stage(cmds) := s if {
	s := last(cmds)
	count(stage(cmds, s)) > 1
}

image_stage(cmds) := parent(cmds, s) if {
	s := last(cmds)
	count(stage(cmds, s)) == 1
}

# The stages whose instructions the image inherits: the last one and,
# FROM by FROM, the earlier stages it is built on (rapx: its last stage
# runs a smoke test FROM the stage that sets the entrypoint).
image_chain(cmds) := graph.reachable(
	{s: {p | some p in [parent(cmds, s)]} | some s in object.keys(from_index(cmds))},
	{last(cmds)},
)

# The names an ARG declares (`ARG A B=1` declares two), and those with a
# default (`NAME=value`).
arg_names(c) := {split(v, "=")[0] | some v in c.Value}

arg_defaults(c) := {split(v, "=")[0] | some v in c.Value; contains(v, "=")}
