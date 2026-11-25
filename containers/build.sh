#!/bin/bash
# Build the pipeline image next to this script, named with the pipeline version:
#   fiberseq-cpg-r9_v<manifest.version>.sif   (version read from ../nextflow.config)
# Usage: containers/build.sh [apptainer|singularity] [extra build options, e.g. --force]
# Without root, needs --fakeroot (subuid/subgid entries for your user).
# Release builds: ./release.sh --release (bumps the version first, then calls this script).
set -euo pipefail
cd "$(dirname "$0")"
TOOL=${1:-apptainer}
shift || true
VERSION=$(sed -n "s/^ *version *= *'\([0-9]*\.[0-9]*\.[0-9]*\)'.*/\1/p" ../nextflow.config | head -1)
[[ -n "$VERSION" ]] || { echo "build.sh: manifest.version not found in nextflow.config" >&2; exit 1; }
SIF="fiberseq-cpg-r9_v${VERSION}.sif"
echo "Building containers/${SIF}"
if [[ -n "${SKIP_BUILD:-}" ]]; then   # testing only: fake image
    : > "$SIF"
    exit 0
fi
"$TOOL" build --fakeroot --build-arg "VERSION=${VERSION}" "$@" "$SIF" fiberseq-cpg-r9.def
