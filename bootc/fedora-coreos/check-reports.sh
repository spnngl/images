#!/usr/bin/env bash
# Summarise the scan reports of the `reports` target, and fail on a failed
# OpenSCAP rule or a fixable Critical vulnerability. Run by build.sh and
# build-bootc.yml.
#
# Usage: bootc/fedora-coreos/check-reports.sh <dir>
#   dir  the `reports` target's output (openscap/results.xml,
#        grype/grype.prom), absolute or from the repository root
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

reports="${1:-}"
[[ -n ${reports} ]] || die "usage: $0 <dir>, the reports target's output"
results="${reports}/openscap/results.xml"
prom="${reports}/grype/grype.prom"
[[ -f ${results} && -f ${prom} ]] || die "no ${results} or ${prom}: build the reports target first"

failed=""
# Rules out of the profile are `notselected`.
grep -o '<result>[a-z]*</result>' "${results}" | awk -F '[<>]' '
    $3 != "notselected" { n[$3]++ }
    END { printf "OpenSCAP:"; for (r in n) printf " %d %s", n[r], r; print "" }'
if grep -qE '<result>(fail|error)</result>' "${results}"; then
    failed+=" OpenSCAP rules failed: ${reports}/openscap/report.html."
fi
# grype.prom holds the fixable vulnerabilities of Medium severity and above.
awk -F '"' '/^grype_vulnerability\{/ { n[$4]++ }
    END { printf "grype, fixable:"; for (s in n) printf " %d %s", n[s], s; print "" }' "${prom}"
if grep -q '^grype_vulnerability{.*severity="Critical"' "${prom}"; then
    failed+=" Fixable Critical vulnerabilities: ${prom}."
fi
[[ -z ${failed} ]] || die "${failed# }"
