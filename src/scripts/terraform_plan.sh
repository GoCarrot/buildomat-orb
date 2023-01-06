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
  I_OUT_PLAN=$(eval echo "${I_OUT_PLAN}")
  I_OUT_LOG=$(eval echo "${I_OUT_LOG}")
  I_OUT_PATH=$(eval echo "${I_OUT_PATH}")
  I_WORKSPACE=$(eval echo "${I_WORKSPACE}")
  I_PATH=$(eval echo "${I_PATH}")
  I_VAR=$(eval echo "${I_VAR}")
  I_VAR_FILE=$(eval echo "${I_VAR_FILE}")

  echo "I_OUT_PLAN"="${I_OUT_PLAN}"
  echo "I_OUT_LOG"="${I_OUT_LOG}"
  echo "I_OUT_PATH"="${I_OUT_PATH}"
  echo "I_WORKSPACE"="${I_WORKSPACE}"
  echo "I_PATH"="${I_PATH}"
  echo "I_VAR"="${I_VAR}"
  echo "I_VAR_FILE"="${I_VAR_FILE}"
}

TFPlan() {
  if [[ ! -d "${I_PATH}" ]]; then
    echo "Path does not exist: \"${I_PATH}\""
    exit 1
  fi

  if [[ "${I_WORKSPACE}" != "" ]]; then
    echo "[INFO] Provisioning workspace: ${I_WORKSPACE}"
    ~/terraform/terraform -chdir="${I_PATH}" workspace select -no-color "${I_WORKSPACE}" || ~/terraform/terraform -chdir="${I_PATH}" workspace new -no-color "${I_WORKSPACE}"
  else
    echo "[INFO] Using default workspace"
  fi

  PLAN_ARGS="-no-color -detailed-exitcode"
  if [[ -n "${I_VAR}" ]]; then
    for var in $(echo "${I_VAR}" | tr ',' '\n'); do
      PLAN_ARGS="$PLAN_ARGS -var $var"
    done
  fi

  if [[ -n "${I_VAR_FILE}" ]]; then
    for var in $(echo "${I_VAR_FILE}" | tr ',' '\n'); do
      PLAN_ARGS="$PLAN_ARGS -var-file $var"
    done
  fi

  mkdir -p "${I_OUT_PATH}"
  set +e
  # PLAN_ARGS here cannot be quoted, we are relying on the word splitting behavior
  # to properly pass in various CLI options.
  # shellcheck disable=SC2086
  ~/terraform/terraform -chdir="${I_PATH}" plan $PLAN_ARGS -out="${I_OUT_PATH}/${I_OUT_PLAN}" | tee "${I_OUT_PATH}/${I_OUT_LOG}"
  plan_retval=$?
  set -e
  if [ $plan_retval -eq 1 ]; then
    exit 1
  fi
  if [ $plan_retval -eq 2 ]; then
    touch "${I_OUT_PATH}/tf_plan_changes"
  fi
}

SetupEnv
TFPlan
