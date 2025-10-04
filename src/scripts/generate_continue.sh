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
  I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES=$(eval echo "${I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES}")
  I_AUTO_DEPLOY_SERVICES=$(eval echo "${I_AUTO_DEPLOY_SERVICES}")
  I_APPROVE_DEPLOY_SERVICES=$(eval echo "${I_APPROVE_DEPLOY_SERVICES}")
  I_PACKER_VERSION=$(eval echo "${I_PACKER_VERSION}")
  I_PACKER_EXCEPT=$(eval echo "${I_PACKER_EXCEPT}")
  I_PACKER_ONLY=$(eval echo "${I_PACKER_ONLY}")
  I_PACKER_LOG=$(eval echo "${I_PACKER_LOG}")
  I_PACKER_PATH=$(eval echo "${I_PACKER_PATH}")
  I_TERRAFORM_VERSION=$(eval echo "${I_TERRAFORM_VERSION}")
  I_PLATFORM=$(eval echo "${I_PLATFORM}")
  I_PACKER_GITHUB_RELEASES_USER=$(eval echo "${I_PACKER_GITHUB_RELEASES_USER}")
  I_PACKER_GPG_KEY_ID=$(eval echo "${I_PACKER_GPG_KEY_ID}")
  I_PACKER_GPG_KEYSERVER=$(eval echo "${I_PACKER_GPG_KEYSERVER}")
  I_CONTEXTS=$(eval echo "${I_CONTEXTS}")
  I_OUT_PATH=$(eval echo "${I_OUT_PATH}")
  I_ORB=$(eval echo "${I_ORB}")

  echo "I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES"="${I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES}"
  echo "I_AUTO_DEPLOY_SERVICES"="${I_AUTO_DEPLOY_SERVICES}"
  echo "I_APPROVE_DEPLOY_SERVICES"="${I_APPROVE_DEPLOY_SERVICES}"
  echo "I_PACKER_VERSION"="${I_PACKER_VERSION}"
  echo "I_PACKER_EXCEPT"="${I_PACKER_EXCEPT}"
  echo "I_PACKER_ONLY"="${I_PACKER_ONLY}"
  echo "I_PACKER_LOG"="${I_PACKER_LOG}"
  echo "I_PACKER_PATH"="${I_PACKER_PATH}"
  echo "I_TERRAFORM_VERSION"="${I_TERRAFORM_VERSION}"
  echo "I_PLATFORM"="${I_PLATFORM}"
  echo "I_PACKER_GITHUB_RELEASES_USER"="${I_PACKER_GITHUB_RELEASES_USER}"
  echo "I_PACKER_GPG_KEY_ID"="${I_PACKER_GPG_KEY_ID}"
  echo "I_PACKER_GPG_KEYSERVER"="${I_PACKER_GPG_KEYSERVER}"
  echo "I_CONTEXTS"="${I_CONTEXTS}"
  echo "I_OUT_PATH"="${I_OUT_PATH}"
  echo "I_ORB"="${I_ORB}"
}

GenerateContinue() {
  if [[ -n "${I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES}" ]]; then
    for service in $(echo "${I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES}" | tr ',' '\n'); do
      AUTODEPLOY_SERVICES="$AUTODEPLOY_SERVICES
        - ${service}"
    done
  else
    AUTODEPLOY_SERVICES='[]'
  fi

  if [[ -n "${I_AUTO_DEPLOY_SERVICES}" ]]; then
    for service in $(echo "${I_AUTO_DEPLOY_SERVICES}" | tr ',' '\n'); do
      AUTODEPLOY_ROLLBACK_SERVICES="$AUTODEPLOY_ROLLBACK_SERVICES
        - ${service}"
    done
  else
    AUTODEPLOY_ROLLBACK_SERVICES='[]'
  fi

  if [[ -n "${I_APPROVE_DEPLOY_SERVICES}" ]]; then
    for service in $(echo "${I_APPROVE_DEPLOY_SERVICES}" | tr ',' '\n'); do
      APPROVE_SERVICES="$APPROVE_SERVICES
        - ${service}"
    done
  else
    APPROVE_SERVICES='[]'
  fi

  if [[ -n "${I_CONTEXTS}" ]]; then
    for context in $(echo "${I_CONTEXTS}" | tr ',' '\n'); do
      CONTEXTS="$CONTEXTS
      - ${context}"
    done
  else
    CONTEXTS='[]'
  fi

  # Suppress the error when read returns 1 because it encountered end of file
  set +e
  read -r -d '' TEMPLATE <<EOF
version: 2.1

orbs:
  buildomat: ${I_ORB}

references:
  auto_deploy_services: &auto_deploy_services
    parameters:
      # These are services that don't run any instances, and a deploy just bumps the launch template
      # with the latest AMI.
      service_name: ${AUTODEPLOY_SERVICES}
  auto_deploy_rollback_services: &auto_deploy_rollback_services
    parameters:
      # These are services that should automatically deploy, but also offer a rollback.
      service_name: ${AUTODEPLOY_ROLLBACK_SERVICES}
  approve_deploy_services: &approve_deploy_services
    parameters:
      # These are services that run instances and I would like a human to press the button.
      service_name: ${APPROVE_SERVICES}
  TERRAFORM_VERSION: &TERRAFORM_VERSION
    ${I_TERRAFORM_VERSION}
  CONTEXTS: &CONTEXTS
    context: ${CONTEXTS}
  packer-build: &packer-build
    <<: *CONTEXTS
    version: "${I_PACKER_VERSION}"
    github_releases_user: "${I_PACKER_GITHUB_RELEASES_USER}"
    gpg_key_id: "${I_PACKER_GPG_KEY_ID}"
    gpg_keyserver: "${I_PACKER_GPG_KEYSERVER}"
    name: "Generate Images (<< pipeline.parameters.build_account_slug >>)"
    image: teakinc/ansible:current
    post-steps:
      - store_artifacts:
          path: "packer/manifests/"
      - persist_to_workspace:
          root: "packer/manifests/"
          paths:
            - "packer-manifest.json"
    path: "${I_PACKER_PATH}"
    var: "region=<< pipeline.parameters.region >>,build_account_canonical_slug=<< pipeline.parameters.build_account_slug >>"
    except: "${I_PACKER_EXCEPT}"
    only: "${I_PACKER_ONLY}"

parameters:
  run-apply:
    type: boolean
    default: false
  environment-active:
    type: boolean
    default: true
  continuation-cache-id:
    type: string
    default: ""
  workspace:
    type: string
    default: ""
  plan-log-url:
    type: string
    default: ""
  region:
    type: string
    default: us-east-1
  build_account_slug:
    type: string
    default: ""
  deploy_account_slug:
    type: string
    default: ""
  # Work around CircleCI brain damage.
  # Continuation pipelines must declare all the same parameters as the setup pipeline, even
  # though it's an error to just reuse those parameters without changes.
  in_build_account_slug:
    type: string
    default: ''
  in_deploy_account_slug:
    type: string
    default: ''

workflows:
  version: 2
  apply-and-build:
    when:
      and:
        - << pipeline.parameters.run-apply >>
        - << pipeline.parameters.environment-active >>
    jobs:
      - buildomat/terraform-slack-on-hold:
          <<: *CONTEXTS
          plan-log-url: << pipeline.parameters.plan-log-url >>
      - hold:
          name: "Human, your approval is required (<< pipeline.parameters.workspace >>)"
          type: approval
          requires:
            - buildomat/terraform-slack-on-hold
      - buildomat/terraform-apply:
          <<: *CONTEXTS
          version: *TERRAFORM_VERSION
          name: "Apply (<< pipeline.parameters.workspace >>)"
          continuation_cache: << pipeline.parameters.continuation-cache-id >>
          path: "terraform"
          workspace: << pipeline.parameters.workspace >>
          requires:
            - "Human, your approval is required (<< pipeline.parameters.workspace >>)"
      - buildomat/packer-build:
          <<: *packer-build
      - buildomat/deployomat-slack-deploy-on-hold: &approve_deploy_notify
          matrix:
            <<: *approve_deploy_services
          <<: *CONTEXTS
          name: "Deploy Hold Notify (<< matrix.service_name >>)?"
          requires:
            - "Apply (<< pipeline.parameters.workspace >>)"
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - hold: &approve_deploy_hold
          matrix:
            <<: *approve_deploy_services
          type: approval
          name: "Run Deploy (<< matrix.service_name >>)?"
          requires:
            - "Apply (<< pipeline.parameters.workspace >>)"
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-deploy: &approve_deploy
          <<: *CONTEXTS
          name: "Deploy << matrix.service_name >>"
          region: << pipeline.parameters.region >>
          account_canonical_slug: << pipeline.parameters.deploy_account_slug >>
          deployomat_canonical_slug: << pipeline.parameters.build_account_slug >>
          # Note that this requires a deploy config for every service.
          deploy_config_file: deploy_configs/<< matrix.service_name >>.json
          matrix:
            <<: *approve_deploy_services
          requires:
            - "Run Deploy (<< matrix.service_name >>)?"
      - buildomat/deployomat-deploy: &auto_deploy
          <<: *CONTEXTS
          name: "Deploy << matrix.service_name >>"
          region: << pipeline.parameters.region >>
          account_canonical_slug: << pipeline.parameters.deploy_account_slug >>
          deployomat_canonical_slug: << pipeline.parameters.build_account_slug >>
          deploy_config_file: deploy_configs/<< matrix.service_name >>.json
          matrix:
            <<: *auto_deploy_services
          requires:
            - "Apply (<< pipeline.parameters.workspace >>)"
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-deploy: &auto_cancel_deploy
          <<: *CONTEXTS
          name: "Deploy << matrix.service_name >>"
          region: << pipeline.parameters.region >>
          account_canonical_slug: << pipeline.parameters.deploy_account_slug >>
          deployomat_canonical_slug: << pipeline.parameters.build_account_slug >>
          deploy_config_file: deploy_configs/<< matrix.service_name >>.json
          matrix:
            <<: *auto_deploy_rollback_services
          requires:
            - "Apply (<< pipeline.parameters.workspace >>)"
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-slack-cancel-on-hold: &approve_cancel_notify
          <<: *CONTEXTS
          name: "Deploy Cancel Notify (<< matrix.service_name >>)"
          matrix:
            <<: *approve_deploy_services
          requires:
            - "Deploy << matrix.service_name >>"
      - buildomat/deployomat-slack-cancel-on-hold: &approve_auto_cancel_notify
          <<: *CONTEXTS
          name: "Deploy Cancel Notify (<< matrix.service_name >>)"
          matrix:
            <<: *auto_deploy_rollback_services
          requires:
            - "Deploy << matrix.service_name >>"
      - hold: &approve_cancel_hold
          matrix:
            <<: *approve_deploy_services
          type: approval
          name: "Cancel Deploy (<< matrix.service_name >>)?"
          requires:
            - "Run Deploy (<< matrix.service_name >>)?"
      - hold: &approve_auto_cancel_hold
          matrix:
            <<: *auto_deploy_rollback_services
          type: approval
          name: "Cancel Deploy (<< matrix.service_name >>)?"
          requires:
            - "Deploy Cancel Notify (<< matrix.service_name >>)"
      - buildomat/deployomat-cancel: &approve_cancel
          <<: *CONTEXTS
          matrix:
            <<: *approve_deploy_services
          name: "Cancel Deploy (<< matrix.service_name >>)!"
          region: << pipeline.parameters.region >>
          account_canonical_slug: << pipeline.parameters.deploy_account_slug >>
          deployomat_canonical_slug: << pipeline.parameters.build_account_slug >>
          requires:
            - "Cancel Deploy (<< matrix.service_name >>)?"
      - buildomat/deployomat-cancel: &approve_auto_cancel
          <<: *CONTEXTS
          matrix:
            <<: *auto_deploy_rollback_services
          name: "Cancel Deploy (<< matrix.service_name >>)!"
          region: << pipeline.parameters.region >>
          account_canonical_slug: << pipeline.parameters.deploy_account_slug >>
          deployomat_canonical_slug: << pipeline.parameters.build_account_slug >>
          requires:
            - "Cancel Deploy (<< matrix.service_name >>)?"
  build-and-deploy-only:
    when:
      and:
        - not: << pipeline.parameters.run-apply >>
        - << pipeline.parameters.environment-active >>
        - << pipeline.parameters.deploy_account_slug >>
    jobs:
      - buildomat/packer-build:
          <<: *packer-build
      - buildomat/deployomat-slack-deploy-on-hold:
          <<: *approve_deploy_notify
          requires:
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - hold:
          <<: *approve_deploy_hold
          requires:
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-deploy:
          <<: *approve_deploy
      - buildomat/deployomat-deploy:
          <<: *auto_deploy
          requires:
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-deploy:
          <<: *auto_cancel_deploy
          requires:
            - "Generate Images (<< pipeline.parameters.build_account_slug >>)"
      - buildomat/deployomat-slack-cancel-on-hold: *approve_cancel_notify
      - buildomat/deployomat-slack-cancel-on-hold: *approve_auto_cancel_notify
      - hold: *approve_cancel_hold
      - hold: *approve_auto_cancel_hold
      - buildomat/deployomat-cancel: *approve_cancel
      - buildomat/deployomat-cancel: *approve_auto_cancel
  build-only:
    when:
      or:
        - not: << pipeline.parameters.environment-active >>
        - and:
            - not: << pipeline.parameters.run-apply >>
            - not: << pipeline.parameters.deploy_account_slug >>
    jobs:
      - buildomat/packer-build:
          <<: *packer-build
EOF
set -e
  echo "${TEMPLATE}" | tee "${I_OUT_PATH}"
}

SetupEnv
GenerateContinue
