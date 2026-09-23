#!/bin/bash
# Point the leech2 formula at a released version and push the change. The
# checksums come from the release's own checksums.txt, so the formula cannot
# disagree with what was published. Run from the root of a tap checkout.
#
# usage: bump-formula.sh <version>

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <version>" >&2
    exit 1
fi

VERSION="$1"
REPO="larsewi/leech2"
FORMULA="Formula/leech2.rb"

WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

gh release download "v${VERSION}" --repo "${REPO}" \
    --pattern checksums.txt --dir "${WORKDIR}"

checksum_for() {
    local asset="leech2-${VERSION}-macos-$1.tar.gz"
    local sha
    sha=$(awk -v asset="${asset}" '$2 == asset { print $1 }' "${WORKDIR}/checksums.txt")
    if [ -z "${sha}" ]; then
        echo "::error::no checksum for ${asset} in the v${VERSION} release" >&2
        exit 1
    fi
    echo "${sha}"
}

url_for() {
    echo "https://github.com/${REPO}/releases/download/v${VERSION}/leech2-${VERSION}-macos-$1.tar.gz"
}

ARM_URL=$(url_for aarch64)
ARM_SHA=$(checksum_for aarch64)
INTEL_URL=$(url_for x86_64)
INTEL_SHA=$(checksum_for x86_64)

# Replace the url and sha256 inside whichever on_arm / on_intel block we are in,
# and pass every other line through untouched.
block=""
while IFS= read -r line; do
    case "${line}" in
    *"on_arm do"*) block="arm" ;;
    *"on_intel do"*) block="intel" ;;
    esac

    case "${line}" in
    *'url "'*)
        if [ "${block}" = "arm" ]; then
            printf '    url "%s"\n' "${ARM_URL}"
            continue
        elif [ "${block}" = "intel" ]; then
            printf '    url "%s"\n' "${INTEL_URL}"
            continue
        fi
        ;;
    *'sha256 "'*)
        if [ "${block}" = "arm" ]; then
            printf '    sha256 "%s"\n' "${ARM_SHA}"
            block=""
            continue
        elif [ "${block}" = "intel" ]; then
            printf '    sha256 "%s"\n' "${INTEL_SHA}"
            block=""
            continue
        fi
        ;;
    esac

    printf '%s\n' "${line}"
done <"${FORMULA}" >"${FORMULA}.new"
mv "${FORMULA}.new" "${FORMULA}"

if git diff --quiet -- "${FORMULA}"; then
    echo "Formula is already at ${VERSION}"
    exit 0
fi

git diff -- "${FORMULA}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "${FORMULA}"
git commit -m "Updated leech2 to ${VERSION}"
git push
