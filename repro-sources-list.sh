#!/bin/bash
#
#   Copyright The repro-sources-list.sh Authors.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# -----------------------------------------------------------------------------
# repro-sources-list.sh:
# configures /etc/apt/sources.list and similar files for installing packages from a snapshot.
#
# This script is expected to be executed inside Dockerfile.
#
# The following distributions are supported:
# - debian:11  (/etc/apt/sources.list)
# - debian:12  (/etc/apt/sources.list.d/debian.sources)
# - archlinux  (/etc/pacman.d/mirrorlist)
#
# For the further information, see https://github.com/reproducible-containers/repro-sources-list.sh
# -----------------------------------------------------------------------------

set -eux -o pipefail

. /etc/os-release
case "${ID}" in
  "debian")
    # : "${SNAPSHOT_ARCHIVE_BASE:=http://snapshot.debian.org/archive/}"
    : "${SNAPSHOT_ARCHIVE_BASE:=http://snapshot-cloudflare.debian.org/archive/}"
    : "${BACKPORTS:=}"
    case "${VERSION_ID}" in
      "10" | "11")
        : "${SOURCE_DATE_EPOCH:=$(stat --format=%Y /etc/apt/sources.list)}"
        ;;
      *)
        : "${SOURCE_DATE_EPOCH:=$(stat --format=%Y /etc/apt/sources.list.d/debian.sources)}"
        rm -f /etc/apt/sources.list.d/debian.sources
    esac
    snapshot="$(printf "%(%Y%m%dT%H%M%SZ)T\n" "${SOURCE_DATE_EPOCH}")"
    # TODO: use the new format for Debian >= 12
    echo "deb [check-valid-until=no] ${SNAPSHOT_ARCHIVE_BASE}debian/${snapshot} ${VERSION_CODENAME} main" >/etc/apt/sources.list
    echo "deb [check-valid-until=no] ${SNAPSHOT_ARCHIVE_BASE}debian-security/${snapshot} ${VERSION_CODENAME}-security main" >>/etc/apt/sources.list
    echo "deb [check-valid-until=no] ${SNAPSHOT_ARCHIVE_BASE}debian/${snapshot} ${VERSION_CODENAME}-updates main" >>/etc/apt/sources.list
    if [ "${BACKPORTS}" = 1 ] ; then echo "deb [check-valid-until=no] ${SNAPSHOT_ARCHIVE_BASE}debian/${snapshot} ${VERSION_CODENAME}-backports main" >>/etc/apt/sources.list; fi
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache
    ;;
  "arch")
    : "${SOURCE_DATE_EPOCH:=$(stat --format=%Y /var/log/pacman.log)}"
    export SOURCE_DATE_EPOCH
    # shellcheck disable=SC2016
    date -d "@${SOURCE_DATE_EPOCH}" '+Server = https://archive.archlinux.org/repos/%Y/%m/%d/$repo/os/$arch' > /etc/pacman.d/mirrorlist
    ;;
  *)
    echo >&2 "Unsupported distribution: ${ID}"
    exit 1
esac

echo "${SOURCE_DATE_EPOCH}" >/SOURCE_DATE_EPOCH
touch "--date=@${SOURCE_DATE_EPOCH}" /SOURCE_DATE_EPOCH
