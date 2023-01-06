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
  I_WORKSPACE=$(eval echo "${I_WORKSPACE}")
  I_PATH=$(eval echo "${I_PATH}")

  echo "I_WORKSPACE"="${I_WORKSPACE}"
  echo "I_PATH"="${I_PATH}"
}

SetupWorkspace() {
  if [[ ${I_WORKSPACE} != "" ]]; then
    echo "[INFO] Provisioning workspace: ${I_WORKSPACE}"
    ~/terraform/terraform -chdir="${I_PATH}" workspace select -no-color "${I_WORKSPACE}" || ~/terraform/terraform -chdir="${I_PATH}" workspace new -no-color "${I_WORKSPACE}"
  else
    echo "[INFO] Using default workspace"
  fi
}

SetupEnv
SetupWorkspace
