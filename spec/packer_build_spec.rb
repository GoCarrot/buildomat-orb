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
require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'open3'

RSpec.describe 'src/commands/packer-build.yml' do
  command = YAML.safe_load_file(File.expand_path('../src/commands/packer-build.yml', __dir__))
  build_env = command['steps'].filter_map { |s| s['run'] }.find { |r| r['name'] == 'Packer Build' }['environment']

  it 'retries lost ssh connections' do
    expect(build_env['ANSIBLE_SSH_RETRIES']).to eq('5')
  end

  it 'pins the python interpreter so discovery cannot fall back to /usr/bin/python' do
    expect(build_env['ANSIBLE_PYTHON_INTERPRETER']).to eq('/usr/bin/python3')
  end
end

RSpec.describe 'packer_build.sh (behavioral)' do
  let(:script) { File.read(File.join(ScriptHarness::SCRIPTS_DIR, 'packer_build.sh')) }

  around do |example|
    Dir.mktmpdir('packer-build-fixture') do |root|
      @root = root
      FileUtils.mkdir_p(File.join(root, 'packer'))
      stub = File.join(root, 'packer', 'packer')
      # One argv entry per line, so a split or merged arg is visible.
      File.write(stub, <<~BASH)
        #!/usr/bin/env bash
        for a in "$@"; do echo "ARG:$a"; done
        echo "PACKER_LOG:$PACKER_LOG"
        exit "${FAKE_PACKER_EXIT:-0}"
      BASH
      FileUtils.chmod(0o755, stub)
      @out_path = File.join(root, 'out', 'nested')
      example.run
    end
  end

  def env(extra = {})
    { 'HOME' => @root, 'I_OUT_LOG' => 'build.log', 'I_OUT_PATH' => @out_path, 'I_PATH' => 'packer',
      'I_ONLY' => '', 'I_EXCEPT' => '', 'I_VAR' => '', 'I_PACKER_LOG' => '0' }.merge(extra)
  end

  # CircleCI runs a step's command as a string, so run it that way.
  def run_step(extra = {})
    Open3.capture3(env(extra), 'bash', '-eo', 'pipefail', '-c', script)
  end

  def argv(stdout) = stdout.scan(/^ARG:(.*)$/).flatten

  it 'passes the base args and path when no only/except/var is set' do
    stdout, _, status = run_step
    expect(status).to be_success
    expect(argv(stdout)).to eq(['build', '-color=false', '-timestamp-ui', 'packer'])
  end

  it 'passes only, except and each comma separated var as its own arg' do
    stdout, _, status = run_step('I_ONLY' => 'amazon-ebs.base', 'I_EXCEPT' => 'vagrant.*',
                                 'I_VAR' => 'region=us-west-2,build_from_account=development-ci-cd')
    expect(status).to be_success
    expect(argv(stdout)).to eq(['build', '-color=false', '-timestamp-ui', '-only=amazon-ebs.base', '-except=vagrant.*',
                                '-var', 'region=us-west-2', '-var', 'build_from_account=development-ci-cd', 'packer'])
  end

  it 'splits var on commas and newlines, skips empty entries, and keeps spaces in a value' do
    stdout, _, status = run_step('I_VAR' => "a=1\nb=2,,x=a b\n")
    expect(status).to be_success
    expect(argv(stdout)).to eq(['build', '-color=false', '-timestamp-ui', '-var', 'a=1', '-var', 'b=2', '-var', 'x=a b', 'packer'])
  end

  it 'prints the final args to the log and hands PACKER_LOG to packer' do
    stdout, _, = run_step('I_EXCEPT' => 'vagrant.*', 'I_PACKER_LOG' => '1')
    expect(stdout).to include('packer build -color=false -timestamp-ui -except=vagrant.\\* packer')
    expect(stdout).to include('PACKER_LOG:1')
  end

  it 'expands $NAME references in params' do
    stdout, _, = run_step('I_VAR' => 'branch=$BRANCH_X', 'BRANCH_X' => 'feat-1')
    expect(argv(stdout)).to include('branch=feat-1')
  end

  it 'tees output to $I_OUT_PATH/$I_OUT_LOG, creating the directory' do
    stdout, _, = run_step
    logged = File.read(File.join(@out_path, 'build.log'))
    expect(logged).to include('ARG:-timestamp-ui')
    expect(stdout).to include('ARG:-timestamp-ui')
  end

  it 'fails the step when packer fails' do
    _, _, status = run_step('FAKE_PACKER_EXIT' => '1')
    expect(status).not_to be_success
  end
end
