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
  I_ROLE_ARN=$(eval echo "${I_ROLE_ARN}")
  I_DURATION_SECONDS=$(eval echo "${I_DURATION_SECONDS}")
  I_ROLE_EXTERNAL_ID=$(eval echo "${I_ROLE_EXTERNAL_ID}")
  I_FORCE_ASSUMPTION=$(eval echo "${I_FORCE_ASSUMPTION}")

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
    eval "$(aws sts assume-role-with-web-identity --role-arn "${I_ROLE_ARN}" --role-session-name "${CIRCLE_PROJECT_REPONAME}-${CIRCLE_WORKFLOW_ID}" --web-identity-token "${CIRCLE_OIDC_TOKEN}" --duration-seconds "${I_DURATION_SECONDS}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
  else
    eval "$(aws sts assume-role-with-web-identity --external-id "${I_ROLE_EXTERNAL_ID}" --role-arn "${I_ROLE_ARN}" --role-session-name "${CIRCLE_PROJECT_REPONAME}-${CIRCLE_WORKFLOW_ID}" --web-identity-token "${CIRCLE_OIDC_TOKEN}" --duration-seconds "${I_DURATION_SECONDS}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
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

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ "${I_FORCE_ASSUMPTION}" == "1" ]; then
  SetupEnv
  AssumeRole
  PersistEnvVars
else
  echo "AWS_ACCESS_KEY_ID is set. Not assuming OIDC role."
fi
