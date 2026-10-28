#!/usr/bin/env bash

# Copyright 2026 Teak.io, Inc.
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

# Resolves whether the environment behind a workspace (or deploy account slug)
# is switched on: account registry -> <prefix>/config/core/active. Hands the
# answer to later steps as ENVIRONMENT_ACTIVE through $BASH_ENV.

SetupEnv() {
  I_WORKSPACE=$(eval echo "${I_WORKSPACE}")

  echo "I_WORKSPACE"="${I_WORKSPACE}"
}

CheckEnvironmentActive() {
  # Default to active for backwards compatibility
  ENVIRONMENT_ACTIVE="true"

  echo "=========================================="
  echo "Environment Activation Check"
  echo "=========================================="

  if [ -z "${I_WORKSPACE}" ]; then
    echo "No workspace specified - treating environment as ACTIVE (default behavior)"
    echo "RESULT: Environment is ACTIVE"
    echo "CONSEQUENCE: Apply and deploy workflows will be available"
    echo "=========================================="
    return
  fi

  # A workspace with no account registry entry has no activation parameter to
  # check, so it stays ACTIVE. Any other lookup failure (access, throttling) is
  # fatal: failing open there could apply an environment that is switched off.
  REGISTRY_ERR=$(mktemp)
  if REGISTRY_VALUE=$(aws ssm get-parameter --name "/omat/account_registry/${I_WORKSPACE}" --output text --query Parameter.Value 2>"${REGISTRY_ERR}"); then
    PARAM_PREFIX=$(echo "${REGISTRY_VALUE}" | jq --raw-output '.prefix // empty' 2>/dev/null || echo "")
  elif grep -q ParameterNotFound "${REGISTRY_ERR}"; then
    PARAM_PREFIX=""
  else
    cat "${REGISTRY_ERR}" >&2
    rm -f "${REGISTRY_ERR}"
    exit 1
  fi
  rm -f "${REGISTRY_ERR}"

  if [ -z "${PARAM_PREFIX}" ]; then
    echo "Workspace: ${I_WORKSPACE}"
    echo "No account registry prefix for this workspace - treating environment as ACTIVE (default behavior)"
    echo "RESULT: Environment is ACTIVE"
    echo "CONSEQUENCE: Apply and deploy workflows will be available"
    echo "=========================================="
    return
  fi

  SSM_PARAM_NAME="${PARAM_PREFIX}/config/core/active"
  echo "Workspace: ${I_WORKSPACE}"
  echo "Checking SSM parameter: ${SSM_PARAM_NAME}"

  # Try to fetch the SSM parameter, suppress errors if parameter doesn't exist
  PARAM_VALUE=$(aws ssm get-parameter \
    --name "${SSM_PARAM_NAME}" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

  if [ -z "$PARAM_VALUE" ]; then
    echo "SSM parameter does not exist - treating environment as ACTIVE (backwards compatible default)"
    echo "RESULT: Environment is ACTIVE"
    echo "CONSEQUENCE: Apply and deploy workflows will be available"
    echo "To disable this environment, create SSM parameter: ${SSM_PARAM_NAME} with value 'inactive'"
  elif [ "$PARAM_VALUE" = "inactive" ]; then
    ENVIRONMENT_ACTIVE="false"
    echo "SSM parameter exists with value: '${PARAM_VALUE}'"
    echo "RESULT: Environment is INACTIVE"
    echo "CONSEQUENCE: Apply and deploy workflows will be SKIPPED"
    echo "CONSEQUENCE: Only Packer image builds will run"
    echo "To re-enable this environment, update SSM parameter: ${SSM_PARAM_NAME} to any value other than 'inactive' or delete the parameter"
  else
    echo "SSM parameter exists with value: '${PARAM_VALUE}'"
    echo "RESULT: Environment is ACTIVE (parameter value is not 'inactive')"
    echo "CONSEQUENCE: Apply and deploy workflows will be available"
    echo "To disable this environment, update SSM parameter: ${SSM_PARAM_NAME} to value 'inactive'"
  fi

  echo "=========================================="
}

PersistEnvironmentActive() {
  echo "export ENVIRONMENT_ACTIVE=${ENVIRONMENT_ACTIVE}" >> "${BASH_ENV}"
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  CheckEnvironmentActive
  PersistEnvironmentActive
fi
