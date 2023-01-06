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
  I_OUT_LOG=$(eval echo "${I_OUT_LOG}")
  I_OUT_PATH=$(eval echo "${I_OUT_PATH}")
  I_PATH=$(eval echo "${I_PATH}")
  I_ONLY=$(eval echo "${I_ONLY}")
  I_EXCEPT=$(eval echo "${I_EXCEPT}")
  I_VAR=$(eval echo "${I_VAR}")
  I_PACKER_LOG=$(eval echo "${I_PACKER_LOG}")

  echo "I_OUT_LOG"="${I_OUT_LOG}"
  echo "I_OUT_PATH"="${I_OUT_PATH}"
  echo "I_PATH"="${I_PATH}"
  echo "I_ONLY"="${I_ONLY}"
  echo "I_EXCEPT"="${I_EXCEPT}"
  echo "I_VAR"="${I_VAR}"
  echo "I_PACKER_LOG"="${I_PACKER_LOG}"
}

PackerBuild() {
  mkdir -p "${I_OUT_PATH}"

  BUILD_ARGS="-color=false -timestamp-ui"

  if [[ -n "${I_ONLY}" ]]; then
    BUILD_ARGS="$BUILD_ARGS -only=${I_ONLY}"
  fi

  if [[ -n "${I_EXCEPT}" ]]; then
    BUILD_ARGS="$BUILD_ARGS -except=${I_EXCEPT}"
  fi

  if [[ -n "${I_VAR}" ]]; then
      for var in $(echo "${I_VAR}" | tr ',' '\n'); do
          BUILD_ARGS="$BUILD_ARGS -var ${var}"
      done
  fi

  # BUILD_ARGS here cannot be quoted, we are relying on the word splitting behavior
  # to properly pass in various CLI options.
  # shellcheck disable=SC2086
  PACKER_LOG=$I_PACKER_LOG ~/packer/packer build $BUILD_ARGS "${I_PATH}" | tee "${I_OUT_PATH}/${I_OUT_LOG}"
}

SetupEnv
PackerBuild
