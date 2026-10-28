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
require 'yaml'

RSpec.describe 'generate_continue.sh param expansion (behavioral)' do
  around do |example|
    Dir.mktmpdir('generate-continue') do |dir|
      @dir = dir
      @out_path = File.join(dir, 'continue.yml')
      example.run
    end
  end

  def generate(overrides = {})
    env = {
      'I_AUTO_DEPLOY_NO_ROLLBACK_SERVICES' => '', 'I_AUTO_DEPLOY_SERVICES' => '',
      'I_APPROVE_DEPLOY_SERVICES' => '', 'I_PACKER_VERSION' => '1.12.0', 'I_PACKER_EXCEPT' => '',
      'I_PACKER_ONLY' => '', 'I_PACKER_LOG' => '', 'I_PACKER_PATH' => 'packer',
      'I_TERRAFORM_VERSION' => '1.10.5', 'I_PLATFORM' => 'linux_amd64',
      'I_PACKER_GITHUB_RELEASES_USER' => 'hashicorp', 'I_PACKER_GPG_KEY_ID' => 'ID',
      'I_PACKER_GPG_KEYSERVER' => 'keys.example', 'I_CONTEXTS' => '', 'I_OUT_PATH' => @out_path,
      'I_ORB' => 'teak/buildomat@0.1'
    }.merge(overrides)
    ScriptHarness.source('generate_continue.sh', 'SetupEnv; GenerateContinue', env: env, chdir: @dir)
  end

  def references
    YAML.safe_load_file(@out_path, aliases: true, permitted_classes: [Symbol])['references']
  end

  it 'keeps every item of a newline separated service list' do
    result = generate('I_AUTO_DEPLOY_SERVICES' => "api\nworker", 'I_CONTEXTS' => "AWS-OIDC-Role\nSlack")

    expect(result.status).to be_success, result.stderr
    expect(result.stderr).not_to include('command not found')
    expect(references.dig('auto_deploy_rollback_services', 'parameters', 'service_name')).to eq(%w[api worker])
    expect(references.dig('CONTEXTS', 'context')).to eq(%w[AWS-OIDC-Role Slack])
  end

  it 'keeps every item of a comma separated service list' do
    expect(generate('I_APPROVE_DEPLOY_SERVICES' => 'api,worker').status).to be_success
    expect(references.dig('approve_deploy_services', 'parameters', 'service_name')).to eq(%w[api worker])
  end

  it 'expands environment references in params' do
    result = generate('I_TERRAFORM_VERSION' => '$TF_VER', 'I_APPROVE_DEPLOY_SERVICES' => "${SVC_A}\n$SVC_B",
                      'TF_VER' => '1.16.4', 'SVC_A' => 'api', 'SVC_B' => 'worker')

    expect(result.status).to be_success, result.stderr
    expect(references['TERRAFORM_VERSION']).to eq('1.16.4')
    expect(references.dig('approve_deploy_services', 'parameters', 'service_name')).to eq(%w[api worker])
  end

  it 'does not run shell syntax found in a param value' do
    marker = File.join(@dir, 'ran')
    result = generate('I_PACKER_PATH' => "packer; touch #{marker}", 'I_PLATFORM' => "$(touch #{marker}.sub)",
                      'I_PACKER_LOG' => "`touch #{marker}.tick`")

    expect(result.status).to be_success, result.stderr
    expect(Dir.children(@dir)).to contain_exactly('continue.yml')
  end
end
