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

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

BUILD_INFO=""
if [ $# -gt 0 ] && [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    BUILD_INFO=".${1,,}"
fi

# check runtime dependencies
[ -x "$(which curl)" ] || { echo "Missing runtime dependency: curl" >&2; exit 1; }
[ -x "$(which jq)" ] || { echo "Missing runtime dependency: jq" >&2; exit 1; }

# read Python package information using PyPi JSON API
PYPI_PACKAGE="postfix-mta-sts-resolver"

PYPI_RESULT="$(mktemp)"
trap "rm -f ${PYPI_RESULT@Q}" ERR EXIT

curl -sSL -o "$PYPI_RESULT" "https://pypi.org/pypi/$PYPI_PACKAGE/json"

if [ ! -e "$PYPI_RESULT" ]; then
    echo "Failed to read PyPi package information of '$PYTHON_PACKAGE'" >&2
    exit 1
fi

# get version of PyPi package
VERSION="$(jq -r '.releases|keys|last' "$PYPI_RESULT")"

if [ -z "$VERSION" ]; then
    echo "Unable to read version of PyPi package '$PYTHON_PACKAGE': Invalid PyPi API response" >&2
    exit 1
elif ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([+~-]|$) ]]; then
    echo "Unable to read version of PyPi package '$PYTHON_PACKAGE': '$VERSION' is no valid version" >&2
    exit 1
fi

VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
VERSION_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
VERSION_MAJOR="${BASH_REMATCH[1]}"

# build tags
BUILD_INFO="$(date --utc +'%Y%m%d')$BUILD_INFO"

TAGS=(
    "v$VERSION" "v$VERSION-$BUILD_INFO"
    "v$VERSION_MINOR" "v$VERSION_MINOR-$BUILD_INFO"
    "v$VERSION_MAJOR" "v$VERSION_MAJOR-$BUILD_INFO"
    "latest"
)

printf 'VERSION="%s"\n' "$VERSION"
printf 'TAGS="%s"\n' "${TAGS[*]}"
