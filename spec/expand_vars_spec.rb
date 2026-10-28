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

# Every script that expands params carries its own copy of ExpandVars (the orb
# can't include a shared file next to a script), so this checks the copies
# agree and that the one they all are does what it claims.
RSpec.describe 'ExpandVars' do
  scripts = Dir.glob(File.join(ScriptHarness::SCRIPTS_DIR, '*.sh')).sort
  block_re = /^# BEGIN ExpandVars.*?^# END ExpandVars$/m
  copies = scripts.to_h { |path| [File.basename(path), File.read(path)[block_re]] }.compact

  it 'is carried by the scripts that expand params' do
    expect(copies.keys).to include('generate_continue.sh', 'generate_multi_root_continue.sh', 'terraform_init.sh')
  end

  it 'has one identical copy per script' do
    expect(copies.values.uniq.length).to eq(1), "copies differ: #{copies.group_by { |_, v| v }.values.map { |g| g.map(&:first) }.inspect}"
  end

  it 'leaves no `eval echo` expansion in any script' do
    offenders = scripts.select { |path| File.read(path).match?(/eval\s+echo/) }.map { |path| File.basename(path) }
    expect(offenders).to be_empty
  end

  it 'is called by every script that defines it, and only defined where called' do
    scripts.each do |path|
      body = File.read(path)
      defined = body.match?(/^ExpandVars\(\)/)
      called = body.match?(/\$\(ExpandVars /)
      expect(defined).to eq(called), "#{File.basename(path)}: defined=#{defined} called=#{called}"
    end
  end

  describe 'behavior' do
    around do |example|
      Dir.mktmpdir('expand-vars') do |dir|
        @dir = dir
        example.run
      end
    end

    def expand(value, env = {})
      result = ScriptHarness.source('terraform_init.sh', 'ExpandVars "$VALUE"', env: { 'VALUE' => value }.merge(env), chdir: @dir)
      expect(result.status).to be_success, result.stderr
      result.stdout
    end

    it 'expands $NAME and ${NAME}' do
      expect(expand('a-$X-${Y}-z', 'X' => 'one', 'Y' => 'two')).to eq('a-one-two-z')
    end

    it 'expands an unset variable to nothing' do
      expect(expand('a${NOPE_NOT_SET}b$NOPE_NOT_SET')).to eq('ab')
    end

    it 'keeps newlines' do
      expect(expand("$X\n${Y}\nplain", 'X' => 'one', 'Y' => 'two')).to eq("one\ntwo\nplain")
    end

    it 'does not expand an unbraced name into the characters after it' do
      expect(expand('$X.suffix $X_2', 'X' => 'one', 'X_2' => 'two')).to eq('one.suffix two')
    end

    it 'does not run command substitution, backticks or separators' do
      marker = File.join(@dir, 'ran')
      value = "$(touch #{marker}.a) `touch #{marker}.b` ; touch #{marker}.c\ntouch #{marker}.d"

      expect(expand(value)).to eq(value)
      expect(Dir.children(@dir)).to be_empty
    end

    it 'leaves quotes, globs, tildes and unsupported ${} forms as written' do
      FileUtils.touch(File.join(@dir, 'vagrant.txt'))
      value = %q(vagrant.* ~/x "q" 'q' ${A:-b} ${A} \\n)

      expect(expand(value)).to eq(value.sub('${A}', ''))
    end

    it 'does not expand references inside an expanded value' do
      expect(expand('$X', 'X' => '$Y', 'Y' => 'nope')).to eq('$Y')
    end

    it 'passes a lone $ and an unterminated ${ through' do
      expect(expand('cost: 5$ ${X $ ')).to eq('cost: 5$ ${X $ ')
    end
  end
end
