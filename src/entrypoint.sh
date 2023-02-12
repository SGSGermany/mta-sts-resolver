#!/bin/sh
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

set -e

if [ $# -eq 0 ] || [ "$1" == "mta-sts-daemon" ]; then
    # run mta-sts-daemon unprivileged
    exec su -p -s /bin/sh mta-sts -c '"$@"' -- '/bin/sh' "$@"
fi

exec "$@"
