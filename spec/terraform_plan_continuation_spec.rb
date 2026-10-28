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
require 'json'

RSpec.describe 'terraform_plan_continuation.sh GenerateContinuation (behavioral)' do
  around do |example|
    Dir.mktmpdir('plan-continuation') do |dir|
      @out_path = File.join(dir, 'out')
      FileUtils.mkdir_p(@out_path)
      example.run
    end
  end

  def generate(changes:)
    FileUtils.touch(File.join(@out_path, 'tf_plan_changes')) if changes
    env = {
      'I_OUT_PATH' => @out_path,
      'I_WORKSPACE' => '',
      'I_OUT_LOG' => 'plan.log',
      'I_CONTINUATION_PARAMETERS' => '',
      'ENVIRONMENT_ACTIVE' => 'true',
      'CIRCLE_WORKFLOW_ID' => 'wf-1',
      'CIRCLE_WORKFLOW_JOB_ID' => 'job-1',
      'CIRCLE_NODE_INDEX' => '0'
    }
    result = ScriptHarness.source('terraform_plan_continuation.sh', 'GenerateContinuation', env: env)
    raise "failed: #{result.stderr}" unless result.status.success?
  end

  it 'links the plan log artifact in continue_params.json when the plan has changes' do
    generate(changes: true)

    params = JSON.parse(File.read(File.join(@out_path, 'continue_params.json')))
    expect(params['plan-log-url']).to eq("https://output.circle-artifacts.com/output/job/job-1/artifacts/0#{@out_path}/plan.log")
    expect(params.keys).to match_array(%w[run-apply environment-active continuation-cache-id workspace plan-log-url])
  end

  it 'records nothing when the plan has no changes' do
    generate(changes: false)

    expect(JSON.parse(File.read(File.join(@out_path, 'continue_params.json')))).not_to have_key('plan-log-url')
  end
end

RSpec.describe 'terraform_plan_continuation.sh CheckEnvironmentActive (behavioral)' do
  around do |example|
    Dir.mktmpdir('env-activation') do |dir|
      @out_path = File.join(dir, 'out')
      FileUtils.mkdir_p(@out_path)
      bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(bin)
      # Stand-in for the aws CLI. Registry lookups answer per FAKE_REGISTRY, the
      # activation parameter per FAKE_ACTIVE (unset means ParameterNotFound).
      File.write(File.join(bin, 'aws'), <<~BASH)
        #!/usr/bin/env bash
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

  def check(registry:, active: nil)
    env = {
      'PATH' => @path,
      'I_OUT_PATH' => @out_path,
      'I_WORKSPACE' => 'workload-dev-0001',
      'I_OUT_LOG' => 'plan.log',
      'I_CONTINUATION_PARAMETERS' => '',
      'CIRCLE_WORKFLOW_ID' => 'wf-1',
      'CIRCLE_WORKFLOW_JOB_ID' => 'job-1',
      'CIRCLE_NODE_INDEX' => '0',
      'FAKE_REGISTRY' => registry
    }
    env['FAKE_ACTIVE'] = active if active
    ScriptHarness.source('terraform_plan_continuation.sh', 'CheckEnvironmentActive; GenerateContinuation; echo "ENVIRONMENT_ACTIVE=${ENVIRONMENT_ACTIVE}"', env: env)
  end

  def continue_params
    JSON.parse(File.read(File.join(@out_path, 'continue_params.json')))
  end

  it 'treats a workspace with no registry entry as ACTIVE' do
    result = check(registry: 'notfound')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
    expect(continue_params['environment-active']).to eq(true)
  end

  it 'does not look up the activation parameter when there is no registry prefix' do
    result = check(registry: 'notfound', active: 'inactive')

    expect(result.stdout).not_to include('Checking SSM parameter')
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
  end

  it 'treats a registry entry with no prefix as ACTIVE' do
    result = check(registry: '{"account":"development-ci-cd"}')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=true')
  end

  it 'fails the job on registry errors other than a missing parameter' do
    result = check(registry: 'denied')

    expect(result.status).not_to be_success
    expect(result.stderr).to include('AccessDeniedException')
    expect(File).not_to exist(File.join(@out_path, 'continue_params.json'))
  end

  it 'still reports INACTIVE when the registry resolves and the parameter says inactive' do
    result = check(registry: '{"prefix":"/teak/workload-dev-0001"}', active: 'inactive')

    expect(result.status).to be_success, result.stderr
    expect(result.stdout).to include('ENVIRONMENT_ACTIVE=false')
    expect(continue_params['environment-active']).to eq(false)
  end
end
