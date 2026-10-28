# frozen_string_literal: true

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

require_relative '../lib/script_harness'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'environment_active.sh (behavioral)' do
  around do |example|
    Dir.mktmpdir('env-activation') do |dir|
      @dir = dir
      @bash_env = File.join(dir, 'bash_env')
      @aws_calls = File.join(dir, 'aws_calls')
      bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(bin)
      # Stand-in for the aws CLI. Registry lookups answer per FAKE_REGISTRY, the
      # activation parameter per FAKE_ACTIVE (unset means ParameterNotFound).
      File.write(File.join(bin, 'aws'), <<~BASH)
        #!/usr/bin/env bash
        echo "$*" >> "#{@aws_calls}"
        case "$*" in
          *account_registry*)
            case "${FAKE_REGISTRY:-}" in
              notfound) echo "An error occurred (ParameterNotFound) when calling the GetParameter operation" >&2; exit 254 ;;
              denied) echo "An error occurred (AccessDeniedException) when calling the GetParameter operation" >&2; exit 254 ;;
              *) echo "${FAKE_REGISTRY}" ;;
            esac ;;
          *config/core/active*)
            if [ -n "${FAKE_ACTIVE:-}" ]; then echo "${FAKE_ACTIVE}"; else echo "ParameterNotFound" >&2; exit 254; fi ;;
          *) echo "unexpected aws call: $*" >&2; exit 1 ;;
        esac
      BASH
      FileUtils.chmod(0o755, File.join(bin, 'aws'))
      @path = "#{bin}:#{ENV.fetch('PATH')}"
      example.run
    end
  end

  def check(registry: 'notfound', active: nil, workspace: 'workload-dev-0001', extra_env: {})
    env = {
      'PATH' => @path,
      'BASH_ENV' => @bash_env,
      'I_WORKSPACE' => workspace,
      'FAKE_REGISTRY' => registry
    }.merge(extra_env)
    env['FAKE_ACTIVE'] = active if active
    ScriptHarness.source('environment_active.sh', 'SetupEnv >/dev/null; CheckEnvironmentActive; PersistEnvironmentActive; echo "ENVIRONMENT_ACTIVE=${ENVIRONMENT_ACTIVE}"', env: env)
  end

  def aws_calls
    File.exist?(@aws_calls) ? File.read(@aws_calls).lines.map(&:chomp) : []
  end

  def handed_off
    File.exist?(@bash_env) ? File.read(@bash_env) : nil
  end

  it 'is ACTIVE and makes no aws call when there is no workspace' do
    result = check(workspace: '')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
    expect(aws_calls).to be_empty
    expect(handed_off).to eq("export ENVIRONMENT_ACTIVE=true\n")
  end

  it 'treats a workspace with no registry entry as ACTIVE, without looking up the activation parameter' do
    result = check(registry: 'notfound', active: 'inactive')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
    expect(aws_calls.grep(/config\/core\/active/)).to be_empty
    expect(handed_off).to eq("export ENVIRONMENT_ACTIVE=true\n")
  end

  it 'treats a registry entry with no prefix as ACTIVE' do
    result = check(registry: '{"account":"development-ci-cd"}', active: 'inactive')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
    expect(result.stdout).not_to include('Checking SSM parameter')
  end

  it 'treats a missing activation parameter as ACTIVE' do
    result = check(registry: '{"prefix":"/teak/workload-dev-0001"}')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
    expect(handed_off).to eq("export ENVIRONMENT_ACTIVE=true\n")
  end

  it 'treats an activation parameter other than inactive as ACTIVE' do
    result = check(registry: '{"prefix":"/teak/workload-prod"}', active: 'active')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
  end

  it 'reports INACTIVE when the registry resolves and the parameter says inactive' do
    result = check(registry: '{"prefix":"/teak/workload-dev-0001"}', active: 'inactive')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=false')
    expect(aws_calls).to include(a_string_matching(%r{/teak/workload-dev-0001/config/core/active}))
    expect(handed_off).to eq("export ENVIRONMENT_ACTIVE=false\n")
  end

  it 'fails, handing nothing off, on registry errors other than a missing parameter' do
    result = check(registry: 'denied')

    expect(result.status).not_to be_success
    expect(result.stderr).to include('AccessDeniedException')
    expect(handed_off).to be_nil
  end

  it 'expands env vars in the workspace the way the other scripts do' do
    result = check(workspace: '$DEPLOY_SLUG', extra_env: { 'DEPLOY_SLUG' => 'workload-dev-0001' })

    expect(result.status).to be_success, result.stderr
    expect(aws_calls).to include(a_string_matching(%r{account_registry/workload-dev-0001}))
  end
end
