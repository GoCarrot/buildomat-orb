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
  I_PLAN_LOG_URL=$(ExpandVars "${I_PLAN_LOG_URL}")
  I_TEMPLATE_NAME=$(ExpandVars "${I_TEMPLATE_NAME}")
  I_ROOT=$(ExpandVars "${I_ROOT}")

  echo "I_PLAN_LOG_URL"="${I_PLAN_LOG_URL}"
  echo "I_TEMPLATE_NAME"="${I_TEMPLATE_NAME}"
  echo "I_ROOT"="${I_ROOT}"
}

BuildMessage() {
  local subject="${CIRCLE_PROJECT_REPONAME} ${CIRCLE_BRANCH}"
  if [[ -n "${I_ROOT}" ]]; then
    subject="${subject}: ${I_ROOT} apply"
  else
    subject="${subject} job"
  fi

  mkdir -p /tmp/teak-orb
  echo "{
      \"text\": \"${subject} on hold, waiting for approval.\",
      \"blocks\": [
        {
          \"type\": \"header\",
          \"text\": {
            \"type\": \"plain_text\",
            \"text\": \"${subject} on hold, waiting for approval. :raised_hand:\",
            \"emoji\": true
          }
        },
        {
          \"type\": \"section\",
          \"fields\": [
            {
              \"type\": \"mrkdwn\",
              \"text\": \"<${I_PLAN_LOG_URL}|Terraform Plan Log>\"
            },
            {
              \"type\": \"mrkdwn\",
              \"text\": \"<https://app.circleci.com/pipelines/workflows/${CIRCLE_WORKFLOW_ID}|View Workflow>\"
            }
          ]
        }
      ]
    }" > /tmp/teak-orb/tf-plan-slack-template.json
    echo "export ${I_TEMPLATE_NAME}=\$(cat /tmp/teak-orb/tf-plan-slack-template.json)" >> "${BASH_ENV}"
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  BuildMessage
fi
