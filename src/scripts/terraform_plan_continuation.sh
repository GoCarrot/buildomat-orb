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
  I_OUT_PATH=$(ExpandVars "${I_OUT_PATH}")
  I_WORKSPACE=$(ExpandVars "${I_WORKSPACE}")
  I_OUT_LOG=$(ExpandVars "${I_OUT_LOG}")
  I_CONTINUATION_PARAMETERS=$(ExpandVars "${I_CONTINUATION_PARAMETERS}")

  echo "I_OUT_PATH"="${I_OUT_PATH}"
  echo "I_WORKSPACE"="${I_WORKSPACE}"
  echo "I_OUT_LOG"="${I_OUT_LOG}"
  echo "I_CONTINUATION_PARAMETERS"="${I_CONTINUATION_PARAMETERS}"
}

GenerateContinuation() {
  # Set by the environment_active.sh step (check-environment-active command).
  : "${ENVIRONMENT_ACTIVE:?ENVIRONMENT_ACTIVE is not set; run check-environment-active first}"

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

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  GenerateContinuation
fi
