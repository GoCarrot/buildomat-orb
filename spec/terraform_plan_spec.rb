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

# Source the real terraform-plan arg assembly, feed it every I_LOCK
# rendering CircleCI can produce, and assert on terraform's
# actual argv -- not on PLAN_ARGS in isolation. `~/terraform/terraform` is a
# hardcoded path in the script, so this stubs terraform by pointing HOME at
# a fixture directory rather than touching the shipped script -- TFPlan runs
# completely unmodified, real assembly and all, and the assertion covers the
# unquoted `$PLAN_ARGS` word-splitting at the call site along with the
# conditional that builds it.
RSpec.describe 'terraform_plan.sh (behavioral)' do
  around do |example|
    Dir.mktmpdir('c-1292-terraform-plan') do |fixture_root|
      @fixture_root = fixture_root

      terraform_dir = File.join(fixture_root, 'terraform')
      FileUtils.mkdir_p(terraform_dir)
      fake_terraform = File.join(terraform_dir, 'terraform')
      File.write(fake_terraform, <<~BASH)
        #!/usr/bin/env bash
        echo "FAKE_TERRAFORM_ARGS:$*"
        exit 0
      BASH
      FileUtils.chmod(0o755, fake_terraform)

      @tf_path = File.join(fixture_root, 'module')
      FileUtils.mkdir_p(@tf_path)
      @out_path = File.join(fixture_root, 'out')

      example.run
    end
  end

  def plan_args_for(i_lock)
    env = {
      'HOME' => @fixture_root,
      'I_OUT_PLAN' => 'plan.out',
      'I_OUT_LOG' => 'plan.log',
      'I_OUT_PATH' => @out_path,
      'I_WORKSPACE' => '',
      'I_PATH' => @tf_path,
      'I_VAR' => '',
      'I_VAR_FILE' => '',
      'I_LOCK' => i_lock
    }
    result = ScriptHarness.source('terraform_plan.sh', 'SetupEnv; TFPlan', env: env)
    unless result.status.success?
      raise "TFPlan failed (status #{result.status.exitstatus}):\nstdout: #{result.stdout}\nstderr: #{result.stderr}"
    end

    result.stdout[/^FAKE_TERRAFORM_ARGS:(.*)$/, 1] || raise("terraform stub was never invoked:\n#{result.stdout}")
  end

  # I_LOCK => whether terraform's argv should contain -lock=false.
  # CircleCI stringifies a boolean `false` param to "0", not "false" --
  # both must unlock; everything else must leave the state lock in place.
  {
    '0' => true,
    'false' => true,
    '1' => false,
    'true' => false,
    '' => false,
    'FALSE' => false,
    'no' => false
  }.each do |i_lock, expect_lock_false|
    it "I_LOCK=#{i_lock.inspect}: terraform's argv #{expect_lock_false ? 'contains' : 'omits'} -lock=false" do
      args = plan_args_for(i_lock)

      if expect_lock_false
        expect(args).to include('-lock=false')
      else
        expect(args).not_to include('-lock=false')
      end
    end
  end
end
