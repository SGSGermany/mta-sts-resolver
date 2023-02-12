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
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" --virtual .run-deps \
    python3

pkg_install "$CONTAINER" --virtual .fetch-deps \
    py3-pip

cmd buildah config \
    --env PYTHONUSERBASE="/usr/local" \
    "$CONTAINER"

pkg_install "$CONTAINER" --virtual .build-deps \
    python3-dev \
    musl-dev \
    gcc \
    make

cmd buildah run "$CONTAINER" -- \
    pip install --user \
        "postfix-mta-sts-resolver[sqlite,uvloop]"

user_add "$CONTAINER" mta-sts 65536 "/var/lib/mta-sts"

cmd buildah run "$CONTAINER" -- \
    chown mta-sts:mta-sts "/var/lib/mta-sts" "/run/mta-sts"

pkg_remove "$CONTAINER" \
    .build-deps

echo + "VERSION=\"\$(buildah run $(quote "$CONTAINER") -- pip show postfix-mta-sts-resolver" \
    "| sed -ne 's/^Version: \(.*\)$/\1/p')\"" >&2
VERSION="$(buildah run "$CONTAINER" -- pip show postfix-mta-sts-resolver \
    | sed -ne 's/^Version: \(.*\)$/\1/p')"

pkg_remove "$CONTAINER" \
    .fetch-deps

echo + "rm -rf …/root/.cache/pip"
rm -rf "$MOUNT/root/.cache/pip"

cleanup "$CONTAINER"

cmd buildah config \
    --volume "/var/lib/mta-sts" \
    --volume "/run/mta-sts" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/lib/mta-sts" \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "mta-sts-daemon" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="MTA STS Resolver" \
    --annotation org.opencontainers.image.description="A container running a daemon which provides MTA-STS policy info for Postfix." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/mta-sts-resolver" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
