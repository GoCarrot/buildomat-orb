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
