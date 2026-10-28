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
require 'json'

RSpec.describe 'ami_update_continue_params.sh BuildParams (behavioral)' do
  def build_params(check:, environment_active: nil, continuation_parameters: '')
    Dir.mktmpdir('ami-params') do |dir|
      env = {
        'I_REGION' => 'us-east-1',
        'I_BUILD_ACCOUNT_SLUG' => 'development-ci-cd',
        'I_DEPLOY_ACCOUNT_SLUG' => 'workload-dev-0001',
        'I_CONTINUATION_PARAMTERS' => continuation_parameters,
        'I_CHECK_ENVIRONMENT_ACTIVE' => check.to_s
      }
      env['ENVIRONMENT_ACTIVE'] = environment_active if environment_active

      @result = ScriptHarness.source('ami_update_continue_params.sh', 'BuildParams', env: env, chdir: dir)
      path = File.join(dir, 'continue_params.json')
      @params = File.exist?(path) ? JSON.parse(File.read(path)) : nil
    end
  end

  it 'sends the same params as before when the check is off' do
    build_params(check: false)

    expect(@result.status).to be_success, @result.stderr
    expect(@params).to eq('region' => 'us-east-1', 'build_account_slug' => 'development-ci-cd', 'deploy_account_slug' => 'workload-dev-0001')
  end

  it 'ignores a stray ENVIRONMENT_ACTIVE when the check is off' do
    build_params(check: false, environment_active: 'false')

    expect(@params).not_to have_key('environment-active')
  end

  it 'sends environment-active false as a boolean for an inactive environment' do
    build_params(check: true, environment_active: 'false')

    expect(@result.status).to be_success, @result.stderr
    expect(@params['environment-active']).to be(false)
  end

  it 'sends environment-active true as a boolean for an active environment' do
    build_params(check: true, environment_active: 'true')

    expect(@params['environment-active']).to be(true)
  end

  it 'fails rather than guess when the check is on and left no result' do
    build_params(check: true)

    expect(@result.status).not_to be_success
    expect(@params).to be_nil
  end

  it 'still merges continuation parameters as strings' do
    build_params(check: true, environment_active: 'false', continuation_parameters: 'foo=bar,baz=boo')

    expect(@params).to include('foo' => 'bar', 'baz' => 'boo', 'environment-active' => false)
  end
end
