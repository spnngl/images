# What every docker-bake.hcl of this repository uses, containers/ and bootc/:
# read first with -f by every bake call (AGENTS.md, "Checks").

# <major>.<minor> of a version: a release line.
function "line" {
  params = [version]
  result = regex("^[0-9]+\\.[0-9]+", version)
}
