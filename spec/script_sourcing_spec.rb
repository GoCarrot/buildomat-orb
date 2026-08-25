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

RSpec.describe 'src/scripts/*.sh source guards' do
  scripts = Dir.glob(File.join(ScriptHarness::SCRIPTS_DIR, '*.sh')).map { |path| File.basename(path) }.sort

  it 'found scripts to check' do
    expect(scripts).not_to be_empty
  end

  scripts.each do |script|
    it "#{script}: sourcing defines SetupEnv, runs nothing, leaves nothing behind" do
      Dir.mktmpdir('source-guard') do |cwd|
        result = ScriptHarness.source(script, 'echo "SETUPENV_DEFINED=$(type -t SetupEnv)"', chdir: cwd)

        expect(result.status).to be_success, "sourcing failed (stderr: #{result.stderr})"
        expect(result.stderr).to eq(''), "sourcing #{script} wrote to stderr: #{result.stderr.inspect}"
        expect(result.stdout.lines.map(&:chomp)).to eq(['SETUPENV_DEFINED=function']),
          "sourcing #{script} produced unexpected stdout -- top-level code likely ran:\n" \
          "stdout: #{result.stdout.inspect}"
        expect(Dir.empty?(cwd)).to be(true),
          "sourcing #{script} left files in its cwd -- top-level code likely ran: #{Dir.children(cwd).inspect}"
      end
    end
  end
end
