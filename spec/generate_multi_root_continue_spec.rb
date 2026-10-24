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
require 'yaml'

RSpec.describe 'generate_multi_root_continue.sh (behavioral)' do
  around do |example|
    Dir.mktmpdir('multi-root-continue') do |dir|
      @plan_base = File.join(dir, 'plans')
      @out_path = File.join(dir, 'out', 'continue.yml')
      example.run
    end
  end

  def plan(root, changes:)
    FileUtils.mkdir_p(File.join(@plan_base, root))
    FileUtils.touch(File.join(@plan_base, root, 'tf_plan_changes')) if changes
  end

  def generate(roots)
    env = {
      'I_ROOTS' => roots,
      'I_PLAN_BASE' => @plan_base,
      'I_TERRAFORM_VERSION' => '1.16.4',
      'I_CONTEXTS' => 'AWS-OIDC-Role,Slack',
      'I_OUT_PATH' => @out_path,
      'I_ORB' => 'teak/buildomat@0.1',
      'CIRCLE_WORKFLOW_ID' => 'wf-123'
    }
    ScriptHarness.source('generate_multi_root_continue.sh', 'SetupEnv; GenerateMultiRootContinue', env: env)
  end

  def jobs
    YAML.safe_load_file(@out_path).dig('workflows', 'apply', 'jobs')
  end

  it 'writes no config when no root has changes' do
    plan('meta', changes: false)
    plan('github', changes: false)

    expect(generate('meta,github').status).to be_success
    expect(File.exist?(@out_path)).to be(false)
  end

  it 'removes a stale config when no root has changes' do
    FileUtils.mkdir_p(File.dirname(@out_path))
    File.write(@out_path, 'stale')
    plan('meta', changes: false)

    expect(generate('meta').status).to be_success
    expect(File.exist?(@out_path)).to be(false)
  end

  it 'holds and applies only the changed root' do
    plan('meta', changes: false)
    plan('production', changes: true)
    plan('github', changes: false)

    expect(generate('meta,production,github').status).to be_success
    expect(jobs.map { |j| j.values.first['name'] }).to eq(['Approve apply (production)', 'Apply (production)'])

    hold, apply = jobs
    expect(hold['hold']['type']).to eq('approval')
    expect(apply['buildomat/terraform-apply']).to include(
      'path' => 'production',
      'plan_path' => "#{@plan_base}/production",
      'continuation_cache' => 'wf-123-production',
      'version' => '1.16.4',
      'context' => %w[AWS-OIDC-Role Slack],
      'use_circle_workspace' => false,
      'requires' => ['Approve apply (production)']
    )
  end

  it 'emits one hold/apply pair per changed root' do
    plan('meta', changes: true)
    plan('production', changes: false)
    plan('github', changes: true)

    expect(generate("meta\nproduction\ngithub").status).to be_success
    expect(jobs.map { |j| j.values.first['name'] }).to eq(
      ['Approve apply (meta)', 'Apply (meta)', 'Approve apply (github)', 'Apply (github)']
    )
    expect(YAML.safe_load_file(@out_path)['orbs']).to eq('buildomat' => 'teak/buildomat@0.1')
  end

  it 'rejects a root name that could break the generated YAML' do
    result = generate('meta",x')

    expect(result.status).not_to be_success
    expect(result.stderr).to include('Invalid root name')
  end
end
