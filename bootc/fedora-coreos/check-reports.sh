#!/usr/bin/env bash
# Summarise the reports of the `reports` target, and fail on a failed
# OpenSCAP rule, a fixable Critical vulnerability or a failed goss check.
# Run by build.sh and build-bootc.yml.
#
# Usage: bootc/fedora-coreos/check-reports.sh <dir>
#   dir  the `reports` target's output (openscap/results.xml,
#        grype/grype.prom, goss/build.tap), absolute or from the
#        repository root
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
tap="${reports}/goss/build.tap"
[[ -f ${results} && -f ${prom} && -f ${tap} ]] ||
    die "no ${results}, ${prom} or ${tap}: build the reports target first"

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
# TAP: a plan line `1..<count>`, then `ok` or `not ok` per check. goss
# writes no plan when it can't read the suite.
awk '/^ok / { ok++ } /^not ok / { nok++ } END { printf "goss: %d ok, %d not ok\n", ok, nok }' "${tap}"
grep '^not ok ' "${tap}" || true
if ! grep -qE '^1\.\.[1-9]' "${tap}"; then
    failed+=" goss ran no check: ${tap}."
elif grep -q '^not ok ' "${tap}"; then
    failed+=" goss checks failed: ${tap}."
fi
[[ -z ${failed} ]] || die "${failed# }"
