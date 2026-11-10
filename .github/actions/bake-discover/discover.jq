# The targets to build: those of the HEAD bake definition that changed.
# Run by action.yml; its comments say what each argument is.
#
# `.` is `git log --format=@%ct --name-only --no-renames`, whole, to date
# each target's SOURCE_DATE_EPOCH.

# A .dockerignore glob as a regular expression, as BuildKit reads it:
# `*` stops at `/`, `**` does not, `**/` also matches nothing.
def toregex:
  gsub("(?<c>[.+(){}|^$\\[\\]\\\\])"; "\\\(.c)")
  | gsub("\\*\\*/"; "\u0001")
  | gsub("\\*\\*"; "\u0002")
  | gsub("\\*"; "[^/]*")
  | gsub("\\?"; "[^/]")
  | gsub("\u0001"; "(.*/)?")
  | gsub("\u0002"; ".*");

# The lines of a .dockerignore: pattern and whether it re-includes.
def compile:
  [
    .[]
    | gsub("^\\s+|\\s+$"; "")
    | select(length > 0 and (startswith("#") | not))
    | startswith("!") as $negated
    | ltrimstr("!")
    | gsub("^/+|/+$"; "")
    | {negated: $negated, re: ("^" + toregex + "$")}
  ];

# "a/b/c" -> ["a", "a/b", "a/b/c"]: a pattern matching a folder matches
# what is in it.
def prefixes:
  split("/") | [range(1; length + 1) as $n | .[:$n] | join("/")];

# The last pattern that matches decides, as in BuildKit.
def kept($patterns):
  prefixes as $prefixes
  | (reduce $patterns[] as $p (
      false;
      if any($prefixes[]; test($p.re)) then ($p.negated | not) else . end
    ))
  | not;

# A file of the repository the target's build reads: what its
# .dockerignore keeps, its Containerfile (or spec), its ignore files.
def read_by($t):
  ($t.context + "/") as $prefix
  | if startswith($prefix) then
      .[($prefix | length):] as $rel
      | $rel == $t.dockerfile
        or $rel == ".dockerignore"
        or $rel == ($t.dockerfile + ".dockerignore")
        or ($rel | kept($t.patterns))
    else
      false
    end;

def commits:
  split("\n")
  | reduce .[] as $line (
      [];
      if $line | startswith("@") then . + [{ct: $line[1:], files: []}]
      elif $line == "" then .
      else .[-1].files += [$line]
      end
    );

. as $log
| ($log | commits) as $commits
| $head[0] as $head
| ($head.target
    | map((.context | sub("/+$"; "")) + "/" + (.dockerfile // "Dockerfile") | sub("/[^/]*$"; ""))
    | unique) as $dirs
| ($head.target
    | to_entries
    | map(
        .key as $id
        | .value as $target
        | ($target.context | sub("/+$"; "")) as $context
        | {
            id: $id,
            context: $context,
            dockerfile: ($target.dockerfile // "Dockerfile"),
            patterns: ($ign[$id] // [] | compile),
            target: $target,
            # Shared bake files, and those beside the target's Containerfile:
            # a context may be shared (bootc/), a folder is one image's.
            bake: (
              ($context + "/" + ($target.dockerfile // "Dockerfile") | sub("/[^/]*$"; "")) as $dir
              | $bakefiles
              | map(
                  select(
                    . as $file
                    | startswith($dir + "/")
                      or all($dirs[]; . as $d | $file | startswith($d + "/") | not)
                  )
                )
            )
          }
      )
  ) as $all_targets
# A change to the workflow or an action: every target, or the sample's.
| ($changed != null
    and any($changed[]; . == (".github/workflows/" + $workflow) or startswith(".github/actions/bake-"))
  ) as $ci
| ($changed == null or ($ci and $sample == null)) as $everything
| $all_targets
| map(
    . as $t
    | select(($t.target.tags // []) | length > 0)
    | select(
        $everything
        or ($ci and IN($t.id; ($sample // [])[]))
        or ($base[0].target[$t.id] != $t.target)
        or any($changed[]; read_by($t))
      )
    | {
        id: $t.id,
        context: $t.context,
        file: ($t.context + "/" + $t.dockerfile),
        args: ($t.target.args // {}),
        arches: ($t.target.platforms // ["linux/amd64", "linux/arm64"] | map(ltrimstr("linux/"))),
        target: ($t.target.target // ""),
        tags: ($t.target.tags // []),
        repositories: (
          reduce (($t.target.tags // [])[] | sub(":[^:/]+$"; "")) as $r (
            [];
            if index([$r]) then . else . + [$r] end
          )
        ),
        # The last commit of what the build reads, unless the target
        # sets it. Per target: other targets' commits keep its cache.
        epoch: (
          if $t.target.args.SOURCE_DATE_EPOCH != null then ""
          else
            (first($commits[] | select(any(.files[]; read_by($t) or IN($t.bake[])))) | .ct)
            // $headct
          end
        ),
        rewritetimestamp: (first($t.target.output[]? | ."rewrite-timestamp" // empty) // "true"),
        allow: (($t.target.entitlements // []) | join(","))
      }
  ) as $targets
| {
    targets: $targets,
    # One build job per target and platform, each on a runner of that platform.
    builds: {
      include: [
        $targets[]
        | . as $t
        | .arches[]
        | {target: $t, platform: {arch: ., runner: (if . == "arm64" then "ubuntu-26.04-arm" else "ubuntu-26.04" end)}}
      ]
    },
    groups: (
      $head.group
      | map_values(.targets | map(select(. as $id | $targets | any(.id == $id))))
    )
  }
