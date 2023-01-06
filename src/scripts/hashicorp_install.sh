#!/usr/bin/env bash

# Copyright 2023 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SetupEnv() {
  I_TOOL=$(eval echo "${I_TOOL}")
  I_VERSION=$(eval echo "${I_VERSION}")
  I_PLATFORM=$(eval echo "${I_PLATFORM}")
  I_GITHUB_RELEASES_USER=$(eval echo "${I_GITHUB_RELEASES_USER}")
  I_GPG_KEY_ID=$(eval echo "${I_GPG_KEY_ID}")
  I_GPG_KEYSERVER=$(eval echo "${I_GPG_KEYSERVER}")

  echo "I_TOOL"="${I_TOOL}"
  echo "I_VERSION"="${I_VERSION}"
  echo "I_PLATFORM"="${I_PLATFORM}"
  echo "I_GITHUB_RELEASES_USER"="${I_GITHUB_RELEASES_USER}"
  echo "I_GPG_KEY_ID"="${I_GPG_KEY_ID}"
  echo "I_GPG_KEYSERVER"="${I_GPG_KEYSERVER}"
}

InstallTool() {
  if [ ! -f ~/"${I_TOOL}/${I_TOOL}" ] || [ "$(~/"${I_TOOL}/${I_TOOL}" version | grep -i -o -E "${I_TOOL} v[0-9]*\.[0-9]*\.[0-9]*(-[a-zA-Z0-9]+)?" | sed "s/${I_TOOL} v//i")" != "${I_VERSION}" ]; then
    echo "Importing signing key"
    gpg --keyserver "${I_GPG_KEYSERVER}" --recv "${I_GPG_KEY_ID}"

    base_url="https://releases.hashicorp.com/<< parameters.tool >>/<< parameters.version >>"
    if [ -n "${I_GITHUB_RELEASES_USER}" ] ; then
      echo "Using Github releases from ${I_GITHUB_RELEASES_USER}"
      base_url="https://github.com/${I_GITHUB_RELEASES_USER}/${I_TOOL}/releases/download/v${I_VERSION}"
    fi

    wget "$base_url/${I_TOOL}_${I_VERSION}_${I_PLATFORM}.zip"
    wget "$base_url/${I_TOOL}_${I_VERSION}_SHA256SUMS"
    wget "$base_url/${I_TOOL}_${I_VERSION}_SHA256SUMS.sig"

    echo "Validating signatures..."
    if ! gpg --batch --verify "${I_TOOL}_${I_VERSION}_SHA256SUMS.sig" "${I_TOOL}_${I_VERSION}_SHA256SUMS" ; then
      echo "SHA256SUMS file not signed?"
      exit 1
    fi

    # Validate checksum
    expected_sha=$(grep "${I_TOOL}_${I_VERSION}_${I_PLATFORM}.zip" < "${I_TOOL}_${I_VERSION}_SHA256SUMS" | awk '{print $1}')
    download_sha=$(shasum -a 256 "${I_TOOL}_${I_VERSION}_${I_PLATFORM}.zip" | cut -d' ' -f1)
    echo "Validating download..."
    if [ "${expected_sha}" != "${download_sha}" ]; then
      echo "Expected SHA256SUM does not match downloaded file, exiting."
      exit 1
    fi

    unzip -o "${I_TOOL}_${I_VERSION}_${I_PLATFORM}.zip" -d ~/"${I_TOOL}"
  fi
}

SetupEnv
InstallTool
