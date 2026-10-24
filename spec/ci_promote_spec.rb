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

# Runs script/ci-promote in a throwaway git repo whose HEAD has the given
# commit message, with a fake `rake` on PATH that records its arguments.
RSpec.describe 'script/ci-promote' do
  script = File.expand_path('../script/ci-promote', __dir__)
  sha = 'abc123def456'

  def run_with_message(script, message, sha)
    Dir.mktmpdir('ci-promote') do |dir|
      bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'rake'), %(#!/bin/sh\necho "$@" >> "#{dir}/rake.log"\n))
      FileUtils.chmod(0o755, File.join(bin, 'rake'))

      repo = File.join(dir, 'repo')
      FileUtils.mkdir_p(repo)
      env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'CIRCLE_SHA1' => sha,
              'GIT_AUTHOR_NAME' => 't', 'GIT_AUTHOR_EMAIL' => 't@example.com',
              'GIT_COMMITTER_NAME' => 't', 'GIT_COMMITTER_EMAIL' => 't@example.com' }
      _, status = Open3.capture2e(env, 'git', 'init', '-q', chdir: repo)
      raise 'git init failed' unless status.success?

      _, status = Open3.capture2e(env, 'git', 'commit', '-q', '--allow-empty', '-m', message, chdir: repo)
      raise 'git commit failed' unless status.success?

      out, status = Open3.capture2e(env, script, chdir: repo)
      log = File.join(dir, 'rake.log')
      [out, status, File.exist?(log) ? File.read(log).lines.map(&:chomp) : []]
    end
  end

  {
    'Promote to: patch' => 'promote:patch[abc123def456]',
    'Promote to: minor' => 'promote:minor[abc123def456]',
    'promote: major' => 'promote:major[abc123def456]',
    'Release stuff. Promote to: Patch' => 'promote:patch[abc123def456]'
  }.each do |subject, expected|
    it "#{subject.inspect} runs rake #{expected}" do
      out, status, calls = run_with_message(script, subject, sha)
      expect(status).to be_success, out
      expect(calls).to eq([expected])
    end
  end

  it 'exits green without promoting when the subject has no promote marker' do
    out, status, calls = run_with_message(script, 'Merge pull request #12 from GoCarrot/maint/c-1936-orb-ci', sha)
    expect(status).to be_success, out
    expect(calls).to be_empty
    expect(out).to match(/nothing to promote/i)
  end

  # C-1190: a marker in the body must not count, only the subject.
  it 'ignores a promote marker in the commit body' do
    out, status, calls = run_with_message(script, "Tidy docs\n\nPromote to: patch\n", sha)
    expect(status).to be_success, out
    expect(calls).to be_empty
  end

  it 'fails loudly, promoting nothing, on a value that is not a bump' do
    out, status, calls = run_with_message(script, 'Promote to: 0.2.0', sha)
    expect(status).not_to be_success
    expect(calls).to be_empty
    expect(out).to include('0.2.0').and include('patch, minor or major')
  end

  it 'fails rather than promoting dev:alpha when CIRCLE_SHA1 is unset' do
    Dir.mktmpdir('ci-promote-nosha') do |dir|
      env = { 'GIT_AUTHOR_NAME' => 't', 'GIT_AUTHOR_EMAIL' => 't@example.com',
              'GIT_COMMITTER_NAME' => 't', 'GIT_COMMITTER_EMAIL' => 't@example.com' }
      Open3.capture2e(env, 'git', 'init', '-q', chdir: dir)
      Open3.capture2e(env, 'git', 'commit', '-q', '--allow-empty', '-m', 'Promote to: patch', chdir: dir)
      out, status = Open3.capture2e(env.merge('CIRCLE_SHA1' => ''), script, chdir: dir)
      expect(status).not_to be_success
      expect(out).to include('CIRCLE_SHA1')
    end
  end
end
