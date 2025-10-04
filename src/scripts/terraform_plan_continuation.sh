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
  I_OUT_PATH=$(eval echo "${I_OUT_PATH}")
  I_WORKSPACE=$(eval echo "${I_WORKSPACE}")
  I_OUT_LOG=$(eval echo "${I_OUT_LOG}")
  I_CONTINUATION_PARAMETERS=$(eval echo "${I_CONTINUATION_PARAMETERS}")

  echo "I_OUT_PATH"="${I_OUT_PATH}"
  echo "I_WORKSPACE"="${I_WORKSPACE}"
  echo "I_OUT_LOG"="${I_OUT_LOG}"
  echo "I_CONTINUATION_PARAMETERS"="${I_CONTINUATION_PARAMETERS}"
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
    echo "CONSEQUENCE: Terraform apply workflow will be available if there are changes"
    echo "=========================================="
    return
  fi

  PARAM_PREFIX=$(aws ssm get-parameter --name "/omat/account_registry/${I_WORKSPACE}" --output text --query Parameter.Value | jq --raw-output '.prefix')
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
    echo "CONSEQUENCE: Terraform apply workflow will be available if there are changes"
    echo "To disable this environment, create SSM parameter: ${SSM_PARAM_NAME} with value 'inactive'"
  elif [ "$PARAM_VALUE" = "inactive" ]; then
    ENVIRONMENT_ACTIVE="false"
    echo "SSM parameter exists with value: '${PARAM_VALUE}'"
    echo "RESULT: Environment is INACTIVE"
    echo "CONSEQUENCE: Terraform apply and deploy workflows will be SKIPPED"
    echo "CONSEQUENCE: Only Packer image builds will run"
    echo "To re-enable this environment, update SSM parameter: ${SSM_PARAM_NAME} to any value other than 'inactive' or delete the parameter"
  else
    echo "SSM parameter exists with value: '${PARAM_VALUE}'"
    echo "RESULT: Environment is ACTIVE (parameter value is not 'inactive')"
    echo "CONSEQUENCE: Terraform apply workflow will be available if there are changes"
    echo "To disable this environment, update SSM parameter: ${SSM_PARAM_NAME} to value 'inactive'"
  fi

  echo "=========================================="
}

GenerateContinuation() {
  CONTINUE_PARAMS=""
  if [ -f "${I_OUT_PATH}"/tf_plan_changes ]; then
    CONTINUE_PARAMS="{\"run-apply\":true, \"environment-active\":${ENVIRONMENT_ACTIVE}, \"continuation-cache-id\": \"${CIRCLE_WORKFLOW_ID}\", \"workspace\":\"${I_WORKSPACE}\", \"plan-log-url\":\"https://output.circle-artifacts.com/output/job/${CIRCLE_WORKFLOW_JOB_ID}/artifacts/${CIRCLE_NODE_INDEX}${I_OUT_PATH}/${I_OUT_LOG}\"}"
  else
    CONTINUE_PARAMS="{\"environment-active\":${ENVIRONMENT_ACTIVE}}"
  fi

  if [[ -n "${I_CONTINUATION_PARAMETERS}" ]]; then
    for var in $(echo "${I_CONTINUATION_PARAMETERS}" | tr ',' '\n'); do
      IFS='=' read -r key value <<< "${var}"
      CONTINUE_PARAMS=$(echo "${CONTINUE_PARAMS}" | jq --arg key "${key}" --arg val "${value}" '. + {($key): $val}')
    done
  fi

  echo "$CONTINUE_PARAMS" > "${I_OUT_PATH}"/continue_params.json
}

SetupEnv
CheckEnvironmentActive
GenerateContinuation
