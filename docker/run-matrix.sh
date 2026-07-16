#!/usr/bin/env bash
# Build + R CMD check --as-cran across R versions via rocker/r-ver images.
# Usage: docker/run-matrix.sh [version ...]   (default: 4.2.3 4.3.3 4.5.1)
set -uo pipefail

VERSIONS=("$@")
[ ${#VERSIONS[@]} -eq 0 ] && VERSIONS=(4.2.3 4.3.3 4.5.1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon not reachable. Start Docker Desktop and retry." >&2
    exit 1
fi

declare -A STATUS
for v in "${VERSIONS[@]}"; do
    tag="sylvester-check:$v"
    log="$LOG_DIR/R-$v.log"
    echo "==== R $v : build image ===="
    if docker build -f "$SCRIPT_DIR/Dockerfile" --build-arg "R_VERSION=$v" \
            -t "$tag" "$REPO_ROOT" 2>&1 | tee "$log"; then
        echo "==== R $v : R CMD check --as-cran ===="
        if docker run --rm "$tag" 2>&1 | tee -a "$log"; then
            STATUS[$v]=PASS
        else
            STATUS[$v]=CHECK-FAIL
        fi
    else
        STATUS[$v]=BUILD-FAIL
    fi
done

echo ""
echo "================ SUMMARY ================"
rc=0
for v in "${VERSIONS[@]}"; do
    printf "R %-8s %s\n" "$v" "${STATUS[$v]}"
    [ "${STATUS[$v]}" = PASS ] || rc=1
done
exit $rc
