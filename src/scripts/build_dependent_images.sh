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
  I_REGION=$(eval echo "${I_REGION}")
  I_AMI_NAME_PREFIX=$(eval echo "${I_AMI_NAME_PREFIX}")
  I_BUILD_ACCOUNT_SLUG=$(eval echo "${I_BUILD_ACCOUNT_SLUG}")

  echo "I_REGION=$I_REGION"
  echo "I_AMI_NAME_PREFIX=$I_AMI_NAME_PREFIX"
  echo "I_BUILD_ACCOUNT_SLUG=$I_BUILD_ACCOUNT_SLUG"

  export I_REGION I_AMI_NAME_PREFIX I_BUILD_ACCOUNT_SLUG
  export AWS_REGION=$I_REGION
}

IdentifyDependents() {
  local PREFIX
  PREFIX=$(aws ssm get-parameter --name "/omat/account_registry/${I_BUILD_ACCOUNT_SLUG}" --output text --query Parameter.Value | jq -r '.prefix')
  DEPENDENTS=$(aws ssm get-parameters-by-path --path "${PREFIX}/config/image_factories/${I_AMI_NAME_PREFIX}/dependents" --recursive --query 'Parameters[*].Value' | jq 'map(fromjson)')
  echo "Identified dependent image builds:"
  echo "$DEPENDENTS" | jq 'map({project_slug, branch, deploy_account})'
}

BuildCommands() {
  local RAW_API_CALLS
  RAW_API_CALLS=$(echo "$DEPENDENTS" |  jq -r 'map({url: "https://circleci.com/api/v2/project/\(.project_slug)/pipeline", data: ({branch: .branch, parameters: {in_build_account_slug: .build_account, in_deploy_account_slug: (.deploy_account // "")}} | tojson | @sh)}) | map("curl -XPOST --data \(.data) -H \"Content-Type: application/json\" -H \("Circle-Token: \($ENV.CIRCLE_TOKEN)" | @sh) \(.url)") | join("\n")')
  # This read will encounter EOF (that's the point), and we want to ignore that "error".
  set +e
  IFS=$'\n' read -r -a API_CALLS -d "" <<< "$RAW_API_CALLS"
  set -e
}

ExecuteCommands() {
  SUCCESS="true"
  for api_call in "${API_CALLS[@]}"; do
    echo "Executing command"
    echo "$api_call"
    API_RESPONSE=$(eval "$api_call")
    echo "$API_RESPONSE"
    API_ID=$(echo "$API_RESPONSE" | jq -r '.id')
    if [ -z "$API_ID" ]; then
      echo "Failed to trigger dependent build!"
      SUCCESS=
    fi
    echo ""
  done

  if [ -z "$SUCCESS" ]; then
    echo "At least one dependent build failed to trigger, failing step."
    exit 1
  fi
}

SetupEnv
IdentifyDependents
BuildCommands
ExecuteCommands
