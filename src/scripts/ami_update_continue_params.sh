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
  I_DEPLOY_ACCOUNT_SLUG=$(eval echo "${I_DEPLOY_ACCOUNT_SLUG}")
  I_BUILD_ACCOUNT_SLUG=$(eval echo "${I_BUILD_ACCOUNT_SLUG}")
  I_CONTINUATION_PARAMTERS=$(eval echo "${I_CONTINUATION_PARAMTERS}")

  echo "I_REGION=$I_REGION"
  echo "I_DEPLOY_ACCOUNT_SLUG=$I_DEPLOY_ACCOUNT_SLUG"
  echo "I_BUILD_ACCOUNT_SLUG=$I_BUILD_ACCOUNT_SLUG"
  echo "I_CONTINUATION_PARAMTERS=$I_CONTINUATION_PARAMTERS"

  export I_REGION I_DEPLOY_ACCOUNT_SLUG I_BUILI_ACCOUNT_SLUG I_CONTINUATION_PARAMTERS
}

BuildParams() {
  PARAMS=$(jq --null-input '{"region": $ENV.I_REGION, "build_account_slug": $ENV.I_BUILD_ACCOUNT_SLUG, "deploy_account_slug": $ENV.I_DEPLOY_ACCOUNT_SLUG}')
  if [[ -n "${I_CONTINUATION_PARAMTERS}" ]]; then
    for var in $(echo "${I_CONTINUATION_PARAMTERS}" | tr ',' '\n'); do
      IFS='=' read -r key value <<< "$var"
      PARAMS=$(echo "$PARAMS" | jq --arg key "$key" --arg val "$value" '. + {($key): $val}')
    done
  fi

  echo "$PARAMS" | tee continue_params.json
}

SetupEnv
BuildParams
