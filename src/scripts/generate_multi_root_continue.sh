#!/usr/bin/env bash

# Copyright 2026 Teak.io, Inc.
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

# Builds a continuation config for a repo with several terraform roots, each
# planned by its own terraform-plan job (out_path <plan base>/<root>). Every
# root whose plan has changes gets an approval hold and an apply of exactly
# that root's planfile, and, if I_SLACK_CONTEXTS is set, a Slack notification
# that runs alongside the hold, not before it. Roots with no changes get nothing. If no root changed,
# no config is written, and the caller skips the continuation.

SetupEnv() {
  # Not eval-expanded like the others: roots may be newline separated, and
  # eval would run every line after the first as a command.
  I_PLAN_BASE=$(eval echo "${I_PLAN_BASE}")
  I_TERRAFORM_VERSION=$(eval echo "${I_TERRAFORM_VERSION}")
  I_CONTEXTS=$(eval echo "${I_CONTEXTS}")
  I_SLACK_CONTEXTS=$(eval echo "${I_SLACK_CONTEXTS}")
  I_OUT_PATH=$(eval echo "${I_OUT_PATH}")
  I_ORB=$(eval echo "${I_ORB}")

  echo "I_ROOTS=${I_ROOTS}"
  echo "I_PLAN_BASE=${I_PLAN_BASE}"
  echo "I_TERRAFORM_VERSION=${I_TERRAFORM_VERSION}"
  echo "I_CONTEXTS=${I_CONTEXTS}"
  echo "I_SLACK_CONTEXTS=${I_SLACK_CONTEXTS}"
  echo "I_OUT_PATH=${I_OUT_PATH}"
  echo "I_ORB=${I_ORB}"
}

ContextsYaml() {
  local contexts="$1"
  if [[ -z "${contexts}" ]]; then
    echo "[]"
    return
  fi
  local list=""
  for context in $(echo "${contexts}" | tr ',' '\n'); do
    list="${list:+${list}, }\"${context}\""
  done
  echo "[${list}]"
}

GenerateMultiRootContinue() {
  local contexts slack_contexts jobs root changed cache_id plan_log_url
  contexts=$(ContextsYaml "${I_CONTEXTS}")
  slack_contexts=$(ContextsYaml "${I_SLACK_CONTEXTS}")
  jobs=""
  changed=()

  for root in $(echo "${I_ROOTS}" | tr ',' '\n'); do
    if [[ ! "${root}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
      echo "Invalid root name: '${root}'" >&2
      exit 1
    fi
    # A plan job always persists its out_path, so a missing directory means a
    # misconfigured out_path/plan_base or a lost persist, not "no changes".
    if [[ ! -d "${I_PLAN_BASE}/${root}" ]]; then
      echo "No plan output for ${root} at ${I_PLAN_BASE}/${root}" >&2
      exit 1
    fi
    if [[ ! -f "${I_PLAN_BASE}/${root}/tf_plan_changes" ]]; then
      echo "${root}: no changes"
      continue
    fi
    # The plan job's workflow id, not ours: a rerun-from-failed gets a new
    # workflow id but keeps the workspace, and the planfile was cached under
    # the original.
    cache_id=$(jq -r '."continuation-cache-id" // empty' "${I_PLAN_BASE}/${root}/continue_params.json")
    if [[ -z "${cache_id}" ]]; then
      echo "${root} has changes but no continuation-cache-id in continue_params.json" >&2
      exit 1
    fi
    if [[ -n "${I_SLACK_CONTEXTS}" ]]; then
      plan_log_url=$(jq -r '."plan-log-url" // empty' "${I_PLAN_BASE}/${root}/continue_params.json")
      if [[ -z "${plan_log_url}" ]]; then
        echo "${root} has changes but no plan-log-url in continue_params.json to link in Slack" >&2
        exit 1
      fi
      jobs="${jobs}
      - buildomat/terraform-slack-on-hold:
          name: \"Notify hold (${root})\"
          context: ${slack_contexts}
          root: \"${root}\"
          plan-log-url: \"${plan_log_url}\""
    fi

    echo "${root}: has changes"
    changed+=("${root}")
    jobs="${jobs}
      - hold:
          name: \"Approve apply (${root})\"
          type: approval
      - buildomat/terraform-apply:
          name: \"Apply (${root})\"
          context: ${contexts}
          version: \"${I_TERRAFORM_VERSION}\"
          path: \"${root}\"
          plan_path: \"${I_PLAN_BASE}/${root}\"
          continuation_cache: \"${cache_id}-${root}-plan\"
          use_circle_workspace: false
          requires:
            - \"Approve apply (${root})\""
  done

  rm -f "${I_OUT_PATH}"
  if [[ ${#changed[@]} -eq 0 ]]; then
    echo "No root has changes; not writing ${I_OUT_PATH}"
    return
  fi

  mkdir -p "$(dirname "${I_OUT_PATH}")"
  cat > "${I_OUT_PATH}" <<YAML
version: 2.1
orbs:
  buildomat: ${I_ORB}
workflows:
  apply:
    jobs:${jobs}
YAML
  cat "${I_OUT_PATH}"
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  GenerateMultiRootContinue
fi
