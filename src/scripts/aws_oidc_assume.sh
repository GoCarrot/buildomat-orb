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

# BEGIN ExpandVars (copies kept identical by spec/expand_vars_spec.rb)
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
  I_ROLE_ARN=$(ExpandVars "${I_ROLE_ARN}")
  I_DURATION_SECONDS=$(ExpandVars "${I_DURATION_SECONDS}")
  I_ROLE_EXTERNAL_ID=$(ExpandVars "${I_ROLE_EXTERNAL_ID}")
  I_FORCE_ASSUMPTION=$(ExpandVars "${I_FORCE_ASSUMPTION}")

  echo "I_REGION=$I_REGION"
  echo "I_ROLE_ARN=$I_ROLE_ARN"
  echo "I_DURATION_SECONDS=$I_DURATION_SECONDS"
  echo "I_ROLE_EXTERNAL_ID=$I_ROLE_EXTERNAL_ID"
  echo "I_FORCE_ASSUMPTION=$I_FORCE_ASSUMPTION"

  export AWS_REGION=$I_REGION
}

AssumeRole() {
  echo "Assuming role ${I_ROLE_ARN}"
  if [ -z "$I_ROLE_EXTERNAL_ID" ]; then
    eval "$(aws sts assume-role-with-web-identity --role-arn "${I_ROLE_ARN}" --role-session-name "${CIRCLE_PROJECT_REPONAME}-${CIRCLE_WORKFLOW_ID}" --web-identity-token "${CIRCLE_OIDC_TOKEN_V2}" --duration-seconds "${I_DURATION_SECONDS}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
  else
    eval "$(aws sts assume-role-with-web-identity --external-id "${I_ROLE_EXTERNAL_ID}" --role-arn "${I_ROLE_ARN}" --role-session-name "${CIRCLE_PROJECT_REPONAME}-${CIRCLE_WORKFLOW_ID}" --web-identity-token "${CIRCLE_OIDC_TOKEN_V2}" --duration-seconds "${I_DURATION_SECONDS}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
  fi
}

PersistEnvVars() {
  echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
  {
    echo "export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
    echo "export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
    echo "export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}"
  } >> "${BASH_ENV}"
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ "${I_FORCE_ASSUMPTION}" == "1" ]; then
    SetupEnv
    AssumeRole
    PersistEnvVars
  else
    echo "AWS_ACCESS_KEY_ID is set. Not assuming OIDC role."
  fi
fi
