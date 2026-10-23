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

RSpec.describe 'terraform_init.sh (behavioral)' do
  around do |example|
    Dir.mktmpdir('terraform-init-fixture') do |fixture_root|
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

      example.run
    end
  end

  # The restored cache can hold a previous backend config; CI never migrates
  # state, so init has to take the checked-in backend block as-is.
  it 'passes -reconfigure to terraform init' do
    env = { 'HOME' => @fixture_root, 'I_PATH' => @tf_path }
    result = ScriptHarness.source('terraform_init.sh', 'SetupEnv; TFInit', env: env)
    unless result.status.success?
      raise "TFInit failed (status #{result.status.exitstatus}):\nstdout: #{result.stdout}\nstderr: #{result.stderr}"
    end

    args = result.stdout[/^FAKE_TERRAFORM_ARGS:(.*)$/, 1] || raise("terraform stub was never invoked:\n#{result.stdout}")
    expect(args).to match(/(\A|\s)init(\s|\z)/)
    expect(args).to include('-reconfigure')
  end
end
