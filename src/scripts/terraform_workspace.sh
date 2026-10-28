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
  I_WORKSPACE=$(ExpandVars "${I_WORKSPACE}")
  I_PATH=$(ExpandVars "${I_PATH}")

  echo "I_WORKSPACE"="${I_WORKSPACE}"
  echo "I_PATH"="${I_PATH}"
}

SetupWorkspace() {
  if [[ ${I_WORKSPACE} != "" ]]; then
    echo "[INFO] Provisioning workspace: ${I_WORKSPACE}"
    ~/terraform/terraform -chdir="${I_PATH}" workspace select -no-color "${I_WORKSPACE}" || ~/terraform/terraform -chdir="${I_PATH}" workspace new -no-color "${I_WORKSPACE}"
  else
    echo "[INFO] Using default workspace"
  fi
}

if [[ -z "${BUILDOMAT_SOURCE_ONLY:-}" ]]; then
  SetupEnv
  SetupWorkspace
fi
