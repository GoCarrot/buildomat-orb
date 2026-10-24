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

RSpec.describe 'terraform_slack_on_hold_message.sh (behavioral)' do
  def message(root:, url: 'https://example.test/plan')
    Dir.mktmpdir('slack-hold') do |dir|
      bash_env = File.join(dir, 'bash_env')
      # BuildMessage writes a fixed path; don't read another run's template.
      FileUtils.rm_f('/tmp/teak-orb/tf-plan-slack-template.json')
      env = {
        'HOME' => dir,
        'BASH_ENV' => bash_env,
        'I_PLAN_LOG_URL' => url,
        'I_TEMPLATE_NAME' => 'TEAK_TF_ON_HOLD',
        'I_ROOT' => root,
        'CIRCLE_PROJECT_REPONAME' => 'arboretum',
        'CIRCLE_BRANCH' => 'main',
        'CIRCLE_WORKFLOW_ID' => 'wf-1'
      }
      # The script writes under /tmp/teak-orb; read the template it exports
      # back out of BASH_ENV the way the slack/notify step would.
      code = "SetupEnv >/dev/null; BuildMessage; source #{bash_env}; printf '%s' \"$TEAK_TF_ON_HOLD\""
      result = ScriptHarness.source('terraform_slack_on_hold_message.sh', code, env: env)
      raise "failed: #{result.stderr}" unless result.status.success?

      JSON.parse(result.stdout)
    end
  end

  it 'names the root and links the plan job when a root is given' do
    json = message(root: 'production')

    expect(json['text']).to eq('arboretum main: production apply on hold, waiting for approval.')
    expect(json['blocks'][0]['text']['text']).to start_with('arboretum main: production apply on hold')
    expect(json['blocks'][1]['fields'][0]['text']).to eq('<https://example.test/plan|Terraform Plan Job (production)>')
  end

  it 'is the original single-root message when no root is given' do
    json = message(root: '')

    expect(json['text']).to eq('arboretum main job on hold, waiting for approval.')
    expect(json['blocks'][1]['fields'][0]['text']).to eq('<https://example.test/plan|Terraform Plan Log>')
  end
end
