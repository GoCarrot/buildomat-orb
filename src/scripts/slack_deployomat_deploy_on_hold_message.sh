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
  I_TEMPLATE_NAME=$(eval echo "${I_TEMPLATE_NAME}")
  I_SERVICE_NAME=$(eval echo "${I_SERVICE_NAME}")

  echo "I_TEMPLATE_NAME"="${I_TEMPLATE_NAME}"
  echo "I_SERVICE_NAME"="${I_SERVICE_NAME}"
}

BuildMessage() {
  if [ -n "$I_SERVICE_NAME" ]; then
    SERVICE_ADDON=" (service: ${I_SERVICE_NAME})"
  fi
  HEADER="${CIRCLE_PROJECT_REPONAME} ${CIRCLE_BRANCH}${SERVICE_ADDON} is ready to deploy, go here to start."
  mkdir -p /tmp/teak-orb
  echo "{
      \"text\": \"${HEADER}\",
      \"blocks\": [
        {
          \"type\": \"header\",
          \"text\": {
            \"type\": \"plain_text\",
            \"text\": \"${HEADER} :fireworks:\",
            \"emoji\": true
          }
        },
        {
          \"type\": \"section\",
          \"fields\": [
            {
              \"type\": \"mrkdwn\",
              \"text\": \"<https://app.circleci.com/pipelines/workflows/${CIRCLE_WORKFLOW_ID}|View Workflow>\"
            }
          ]
        }
      ]
    }" > /tmp/teak-orb/deploy-deploy-slack-template.json
    echo "export ${I_TEMPLATE_NAME}=\$(cat /tmp/teak-orb/deploy-cancel-slack-template.json)" >> "${BASH_ENV}"
}

SetupEnv
BuildMessage
