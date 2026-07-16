#!/usr/bin/env bash
# Build a source tarball from /pkg, then run R CMD check --as-cran on it.
#
# The image ships LaTeX, so this runs the FULL --as-cran check including the
# PDF reference manual — i.e. exactly what CRAN runs. This is both the
# cross-version compatibility gate and the CRAN-readiness gate.
#
# Exit code propagates to `docker run`. On failure we dump the install log and
# any test-failure output so the captured log explains *why* (e.g. an R version
# below the DESCRIPTION floor fails to install here).
set -uo pipefail

echo "=== R version ==="
R --version | head -1

# Fresh copy so we never pick up Windows-built .o/.dll artifacts.
rm -rf /work/pkg
cp -r /pkg /work/pkg
rm -f /work/pkg/src/*.o /work/pkg/src/*.so /work/pkg/src/*.dll

cd /work
echo "=== R CMD build ==="
if ! R CMD build /work/pkg; then
    echo "=== R CMD build FAILED ==="
    exit 1
fi

TARBALL="$(ls -1t sylvester_*.tar.gz | head -1)"
echo "Built: ${TARBALL}"

echo "=== R CMD check --as-cran ==="
set +e
R CMD check --as-cran "${TARBALL}"
CHECK_RC=$?
set -e

# Self-documenting failure: surface the install log (holds the R-version-floor
# rejection) and any test diffs, so the run log is decisive on its own.
if [ "${CHECK_RC}" -ne 0 ]; then
    echo "=== check FAILED (rc=${CHECK_RC}); dumping diagnostics ==="
    if [ -f /work/sylvester.Rcheck/00install.out ]; then
        echo "----- 00install.out -----"
        cat /work/sylvester.Rcheck/00install.out
    fi
    for f in /work/sylvester.Rcheck/tests/*.Rout.fail; do
        [ -f "$f" ] && { echo "----- $f -----"; cat "$f"; }
    done
    exit "${CHECK_RC}"
fi

echo "=== check complete: OK ==="
