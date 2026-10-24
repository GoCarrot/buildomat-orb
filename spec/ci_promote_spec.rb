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

require 'open3'
require 'tmpdir'
require 'fileutils'

# Runs script/ci-promote with a fake `rake` on PATH that records its arguments.
RSpec.describe 'script/ci-promote' do
  script = File.expand_path('../script/ci-promote', __dir__)
  sha = 'abc123def456'

  def run_promote(script, args, sha)
    Dir.mktmpdir('ci-promote') do |dir|
      bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'rake'), %(#!/bin/sh\necho "$@" >> "#{dir}/rake.log"\n))
      FileUtils.chmod(0o755, File.join(bin, 'rake'))

      env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'CIRCLE_SHA1' => sha }
      out, status = Open3.capture2e(env, script, *args)
      log = File.join(dir, 'rake.log')
      [out, status, File.exist?(log) ? File.read(log).lines.map(&:chomp) : []]
    end
  end

  %w[patch minor major].each do |bump|
    it "#{bump} runs rake promote:#{bump}[<sha>]" do
      out, status, calls = run_promote(script, [bump], sha)
      expect(status).to be_success, out
      expect(calls).to eq(["promote:#{bump}[abc123def456]"])
    end
  end

  ['', '0.2.0', 'patch; echo hi'].each do |bad|
    it "refuses #{bad.inspect} as a bump, promoting nothing" do
      out, status, calls = run_promote(script, bad.empty? ? [] : [bad], sha)
      expect(status).not_to be_success
      expect(calls).to be_empty
      expect(out).to include('usage')
    end
  end

  it 'fails rather than promoting dev:alpha when CIRCLE_SHA1 is unset' do
    out, status, calls = run_promote(script, ['patch'], '')
    expect(status).not_to be_success
    expect(calls).to be_empty
    expect(out).to include('CIRCLE_SHA1')
  end
end
