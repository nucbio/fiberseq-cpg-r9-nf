#!/bin/bash
# Bump the version, commit and push. With --release also build the versioned
# .sif, tag the repo and push the tag (repo tag == .sif version).
#
# Usage: ./release.sh -m "message" [--minor|--major] [--release]
#   default    patch +1          0.0.3 -> 0.0.4
#   --minor    minor +1, patch 0 0.0.3 -> 0.1.0
#   --major    major +1, rest 0  0.4.3 -> 1.0.0
#   --release  build containers/fiberseq-cpg-r9_vX.Y.Z.sif, point params.container
#              at it, commit "Release vX.Y.Z: <msg>", tag vX.Y.Z, push branch + tag
#
# Version source: manifest.version in nextflow.config.
set -euo pipefail
cd "$(dirname "$0")"

MSG="" BUMP=patch RELEASE=0
while (($#)); do
    case "$1" in
        -m)        MSG=${2:-}; shift 2 || { echo "-m needs a message" >&2; exit 1; } ;;
        --minor)   BUMP=minor; shift ;;
        --major)   BUMP=major; shift ;;
        --release) RELEASE=1; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)         echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
[[ -n "$MSG" ]] || { echo "Missing -m \"message\"" >&2; exit 1; }

CONFIG=nextflow.config
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == main ]] || { echo "Not on main (on '$BRANCH')" >&2; exit 1; }

if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    git fetch -q origin main
    if ! git merge-base --is-ancestor origin/main HEAD; then
        echo "Local main is behind origin/main: pull first" >&2; exit 1
    fi
fi

OLD=$(sed -n "s/^ *version *= *'\([0-9]*\.[0-9]*\.[0-9]*\)'.*/\1/p" "$CONFIG" | head -1)
[[ -n "$OLD" ]] || { echo "manifest.version not found in $CONFIG" >&2; exit 1; }
IFS=. read -r MA MI PA <<<"$OLD"
case "$BUMP" in
    patch) PA=$((PA + 1)) ;;
    minor) MI=$((MI + 1)); PA=0 ;;
    major) MA=$((MA + 1)); MI=0; PA=0 ;;
esac
NEW="$MA.$MI.$PA"
TAG="v$NEW"

if ((RELEASE)) && git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag $TAG already exists" >&2; exit 1
fi

echo "Version $OLD -> $NEW"
sed -i "s/^\( *version *= *\)'$OLD'/\1'$NEW'/" "$CONFIG"

if ((RELEASE)); then
    if ! containers/build.sh apptainer; then
        sed -i "s/^\( *version *= *\)'$NEW'/\1'$OLD'/" "$CONFIG"
        echo "Container build failed: version restored to $OLD, nothing committed" >&2
        exit 1
    fi
    sed -i "s|containers/fiberseq-cpg-r9_v[0-9.]*\.sif\"|containers/fiberseq-cpg-r9_${TAG}.sif\"|" "$CONFIG"
    git add -A
    git commit -q -m "Release $TAG: $MSG"
    git tag -a "$TAG" -m "Release $TAG: $MSG"
    git push -u origin main "$TAG"
    echo
    echo "Released $TAG"
    echo "  image:   containers/fiberseq-cpg-r9_${TAG}.sif (upload to Zenodo by hand)"
    url=$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
    echo "  release: ${url}/releases/new?tag=${TAG}"
else
    git add -A
    git commit -q -m "$MSG"
    git push -u origin main
fi
