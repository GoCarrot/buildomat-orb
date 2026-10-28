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

# BEGIN ExpandVars (identical in every script that expands params; spec/expand_vars_spec.rb keeps the copies in sync)
# Expands $NAME and ${NAME} from the environment and nothing else: no command
# execution, quoting, globbing or word splitting, so a param value is data.
ExpandVars() {
  local rest="$1" out="" name
  # shellcheck disable=SC2016 # a regex, not a shell expansion
  local re='\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))'
  while [[ "${rest}" =~ ${re} ]]; do
    name="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
    out="${out}${rest%%"${BASH_REMATCH[0]}"*}${!name:-}"
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  printf '%s' "${out}${rest}"
}
# END ExpandVars

SetupEnv() {
  I_REGION=$(ExpandVars "${I_REGION}")
  I_DEPLOY_ACCOUNT_SLUG=$(ExpandVars "${I_DEPLOY_ACCOUNT_SLUG}")
  I_BUILD_ACCOUNT_SLUG=$(ExpandVars "${I_BUILD_ACCOUNT_SLUG}")
  I_CONTINUATION_PARAMTERS=$(ExpandVars "${I_CONTINUATION_PARAMTERS}")

  echo "I_REGION=$I_REGION"
  echo "I_DEPLOY_ACCOUNT_SLUG=$I_DEPLOY_ACCOUNT_SLUG"
  echo "I_BUILD_ACCOUNT_SLUG=$I_BUILD_ACCOUNT_SLUG"
  echo "I_CONTINUATION_PARAMTERS=$I_CONTINUATION_PARAMTERS"

  export I_REGION I_DEPLOY_ACCOUNT_SLUG I_BUILD_ACCOUNT_SLUG I_CONTINUATION_PARAMTERS
}

BuildParams() {
  PARAMS=$(jq --null-input '{"region": $ENV.I_REGION, "build_account_slug": $ENV.I_BUILD_ACCOUNT_SLUG, "deploy_account_slug": $ENV.I_DEPLOY_ACCOUNT_SLUG}')
  # Only when asked: the check-environment-active step ran, so ENVIRONMENT_ACTIVE
  # is its answer. Otherwise leave the key out and the consumer's default holds.
  if [[ "${I_CHECK_ENVIRONMENT_ACTIVE:-false}" == "true" ]]; then
    : "${ENVIRONMENT_ACTIVE:?ENVIRONMENT_ACTIVE is not set; run check-environment-active first}"
    PARAMS=$(echo "$PARAMS" | jq --argjson active "$ENVIRONMENT_ACTIVE" '. + {"environment-active": $active}')
  fi

  if [[ -n "${I_CONTINUATION_PARAMTERS}" ]]; then
    for var in $(echo "${I_CONTINUATION_PARAMTERS}" | tr ',' '\n'); do
      IFS='=' read -r key value <<< "$var"
      PARAMS=$(echo "$PARAMS" | jq --arg key "$key" --arg val "$value" '. + {($key): $val}')
    done
  fi

  echo "$PARAMS" | tee continue_params.json
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  BuildParams
fi
