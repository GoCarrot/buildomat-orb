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

require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'

# Runs script/ci-promote-gate in a throwaway git repo whose HEAD has the given
# commit message, with a fake `rake` on PATH that stands in for the CHANGELOG
# preflight.
RSpec.describe 'script/ci-promote-gate' do
  script = File.expand_path('../script/ci-promote-gate', __dir__)

  def run_with_message(script, message, preflight_ok: true)
    Dir.mktmpdir('ci-promote-gate') do |dir|
      bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'rake'), <<~SH)
        #!/bin/sh
        echo "$@" >> "#{dir}/rake.log"
        #{preflight_ok ? 'echo 0.1.14' : 'echo "CHANGELOG is not ready" >&2; exit 1'}
      SH
      FileUtils.chmod(0o755, File.join(bin, 'rake'))

      repo = File.join(dir, 'repo')
      FileUtils.mkdir_p(repo)
      params = File.join(dir, 'params.json')
      File.write(params, 'stale')
      env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'PROMOTE_PARAMS_FILE' => params,
              'GIT_AUTHOR_NAME' => 't', 'GIT_AUTHOR_EMAIL' => 't@example.com',
              'GIT_COMMITTER_NAME' => 't', 'GIT_COMMITTER_EMAIL' => 't@example.com' }
      _, status = Open3.capture2e(env, 'git', 'init', '-q', chdir: repo)
      raise 'git init failed' unless status.success?

      _, status = Open3.capture2e(env, 'git', 'commit', '-q', '--allow-empty', '-m', message, chdir: repo)
      raise 'git commit failed' unless status.success?

      out, status = Open3.capture2e(env, script, chdir: repo)
      log = File.join(dir, 'rake.log')
      [out, status,
       File.exist?(log) ? File.read(log).lines.map(&:chomp) : [],
       File.exist?(params) ? File.read(params) : nil]
    end
  end

  {
    'Promote to: patch' => 'patch',
    'Promote to: minor' => 'minor',
    'promote: major' => 'major',
    'Release stuff. Promote to: Patch' => 'patch'
  }.each do |subject, bump|
    it "#{subject.inspect} runs the #{bump} preflight and writes the continuation parameters" do
      out, status, calls, params = run_with_message(script, subject)
      expect(status).to be_success, out
      expect(calls).to eq(["--silent promote:preflight[#{bump}]"])
      expect(JSON.parse(params)).to eq('bump' => bump, 'orb-version' => '0.1.14')
    end
  end

  it 'writes no parameters, and removes stale ones, when the subject has no promote marker' do
    out, status, calls, params = run_with_message(script, 'Merge pull request #12 from GoCarrot/maint/c-1936-orb-ci')
    expect(status).to be_success, out
    expect(calls).to be_empty
    expect(params).to be_nil
    expect(out).to match(/nothing to promote/i)
  end

  it 'ignores a promote marker in the commit body' do
    out, status, calls, params = run_with_message(script, "Tidy docs\n\nPromote to: patch\n")
    expect(status).to be_success, out
    expect(calls).to be_empty
    expect(params).to be_nil
  end

  it 'fails loudly, continuing nothing, on a value that is not a bump' do
    out, status, calls, params = run_with_message(script, 'Promote to: 0.2.0')
    expect(status).not_to be_success
    expect(calls).to be_empty
    expect(params).to be_nil
    expect(out).to include('0.2.0').and include('patch, minor or major')
  end

  it 'fails, continuing nothing, when the CHANGELOG preflight fails' do
    out, status, _calls, params = run_with_message(script, 'Promote to: patch', preflight_ok: false)
    expect(status).not_to be_success
    expect(params).to be_nil
    expect(out).to include('CHANGELOG is not ready')
  end
end
