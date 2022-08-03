#!/bin/bash
# MTA STS Resolver
# A container running a daemon which provides MTA-STS policy info for Postfix.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/common-traps.sh.inc"
source "$CI_TOOLS_PATH/helper/chkupd.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

TAG="${TAGS%% *}"
PYPI_PACKAGES=( "postfix-mta-sts-resolver[sqlite,uvloop]" )

# check whether the base image was updated
chkupd_baseimage "$REGISTRY/$OWNER/$IMAGE" "$TAG" || exit 0

# check whether PyPi packages were updated
chkupd_pypi() {
    local IMAGE="$1"
    shift

    echo + "CONTAINER=\"\$(buildah from $(quote "$IMAGE"))\"" >&2
    local CONTAINER="$(buildah from "$IMAGE" || true)"

    if [ -z "$CONTAINER" ]; then
        echo "Failed to pull image '$IMAGE': No image with this tag found" >&2
        echo "Image rebuild required" >&2
        echo "build"
        return 1
    fi

    trap_exit buildah rm "$CONTAINER"

    cmd buildah run --user root "$CONTAINER" -- \
        apk add --no-cache py3-pip >&2

    echo + "PACKAGE_UPGRADES=\"\$(buildah run --user root $(quote "$CONTAINER") -- pip list --user --outdated)\"" >&2
    local PACKAGE_UPGRADES="$(buildah run --user root "$CONTAINER" -- pip list --user --outdated)"

    if [ -n "$PACKAGE_UPGRADES" ]; then
        echo "Image is out of date: PyPi package upgrades are available" >&2
        echo "$PACKAGE_UPGRADES" >&2
        echo "Image rebuild required" >&2
        echo "build"
        return 1
    fi
}

chkupd_pypi "$REGISTRY/$OWNER/$IMAGE:$TAG" "${PYPI_PACKAGES[@]}" || exit 0
