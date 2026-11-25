# Prometheus' text format, for node-exporter's textfile collector: the metrics
# of usr/libexec/openscap-scan, usr/libexec/etc-diff, usr/libexec/audit-metrics,
# usr/libexec/bootc-metrics and usr/libexec/zram-metrics.
#
# Nushell of Fedora's package (0.99): no syntax of a later release.

# Label values escape \, " and newline.
def labels []: record -> string {
    let pairs = $in | transpose key value | each {|l|
        let value = $l.value | into string
            | str replace --all '\' '\\' | str replace --all '"' '\"' | str replace --all "\n" '\n'
        $'($l.key)="($value)"'
    }
    if ($pairs | is-empty) { '' } else { $"{($pairs | str join ',')}" }
}

# A gauge, or with --counter a counter, from rows of {labels, value}.
export def metric [name: string, help: string, --counter]: list<record> -> list<string> {
    let rows = $in
    let type = if $counter { 'counter' } else { 'gauge' }
    [$"# HELP ($name) ($help)" $"# TYPE ($name) ($type)"]
        | append ($rows | each {|r| $"($name)($r.labels | labels) ($r.value)" })
}

# A metric's one row, without labels; none for null.
export def one []: any -> list<record> {
    if $in == null { [] } else { [{labels: {}, value: $in}] }
}

# Written whole, then renamed: the collector never reads half a file.
export def save-metrics [file: string]: list<string> -> nothing {
    $in | str join "\n" | $"($in)\n" | save --force $"($file).tmp"
    mv --force $"($file).tmp" $file
}
