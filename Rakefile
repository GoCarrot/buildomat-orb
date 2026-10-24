# frozen_string_literal: true

# Copyright 2023 Teak.io, Inc.
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

require 'tempfile'
require 'open3'
require_relative 'lib/changelog_gate'

ORGANIZATION = 'teak'
ORB_NAME = 'buildomat'

def with_packed_orb
  Tempfile.open('orb') do |file|
    `circleci orb pack src > #{file.path}`
    puts "Packed orb to `#{file.path}`"
    yield file.path
  end
end

def registry_version
  info = `circleci orb info #{ORGANIZATION}/#{ORB_NAME}`
  match = info.match(/^Latest: #{ORGANIZATION}\/#{ORB_NAME}@(\S+)/)
  raise "Could not determine the published version of #{ORGANIZATION}/#{ORB_NAME} from `circleci orb info`" unless match

  match[1]
end

def changelog_text
  File.read('CHANGELOG.md')
end

def fail_loudly(message)
  $stderr.puts message
  exit 1
end

# Pre-check: catches "forgot the entry" / "entry is stale" / "entry is for a
# different bump" before anything ships.
def ensure_changelog_documents_next_version!(bump, published = registry_version)
  return ChangelogGate.next_version(published, bump) if ChangelogGate.documents_next_version?(changelog_text, published, bump)

  fail_loudly(<<~MSG)
    CHANGELOG.md's top entry (###{ChangelogGate.top_version(changelog_text)}) is not the version a #{bump} promote will publish
    (#{ChangelogGate.next_version(published, bump)}, after #{ORGANIZATION}/#{ORB_NAME}@#{published}).
    Add or retitle the CHANGELOG.md entry before promoting.
  MSG
end

# Post-check: `circleci orb publish promote` is irreversible, so this can
# only catch drift after the fact -- but it catches the exact-version
# mismatch (e.g. CHANGELOG titled 0.2.0, actually published 0.1.11).
def ensure_changelog_matches_published_version!(promote_output)
  published = ChangelogGate.parse_promoted_version(promote_output, ORGANIZATION, ORB_NAME)
  return if ChangelogGate.documents_version?(changelog_text, published)

  fail_loudly(<<~MSG)
    #{ORGANIZATION}/#{ORB_NAME}@#{published} is now published, but CHANGELOG.md's top entry is
    ###{ChangelogGate.top_version(changelog_text)}, not ###{published}.
    Fix CHANGELOG.md's top entry to ###{published} now -- the version is already live and this can't be undone.
  MSG
end

def promote(label:, version:)
  ensure_changelog_documents_next_version!(version)

  output, status = Open3.capture2e("circleci orb publish promote #{ORGANIZATION}/#{ORB_NAME}@#{label} #{version}")
  puts output
  raise "circleci orb publish promote failed:\n#{output}" unless status.success?

  ensure_changelog_matches_published_version!(output)
end

desc 'Validate the orb'
task :validate do
  with_packed_orb do |orbfile|
    sh "circleci orb validate #{orbfile}", verbose: false
  end
end

desc 'Run shellcheck on all scripts'
task :shellcheck do
  sh 'shellcheck src/scripts/* script/*'
end

desc 'Run the Ruby unit tests'
task :spec do
  sh 'rspec', verbose: false
end

desc 'Validate the orb, run shellcheck on all scripts, and run the Ruby unit tests'
task :test => [:validate, :shellcheck, :spec]

desc 'Publish the orb to a dev label (rake publish[label]; default alpha)'
task :publish, [:label] do |_t, args|
  args.with_defaults(label: 'alpha')
  with_packed_orb do |orbfile|
    sh "circleci orb publish #{orbfile} #{ORGANIZATION}/#{ORB_NAME}@dev:#{args.label}", verbose: false
  end
end

desc 'Promote a dev label (default alpha) to production, bumping patch/minor/major'
namespace :promote do
  desc 'Fail unless CHANGELOG.md documents the version a bump will publish; print that version'
  task :preflight, [:bump] do |_t, args|
    puts ensure_changelog_documents_next_version!(args.fetch(:bump))
  end

  %w[patch minor major].each do |version|
    desc "Promote dev:<label> (default alpha) to production and bump the #{version} in version"
    task version.to_sym, [:label] do |_t, args|
      args.with_defaults(label: 'alpha')
      promote(label: "dev:#{args.label}", version: version)
    end
  end

  task :default => :patch
end

namespace :dev do
  def param_template(file, env_inputs)
    if env_inputs.length == 0
      $stderr.puts "Must specify at least one input."
      exit 1
    end

    require 'erb'
    tpl = ERB.new(File.read(File.expand_path("templates/#{file}.erb", __dir__)), trim_mode: '<>')
    puts tpl.result(binding)
  end

  desc "Given a list of parameters generates a CircleCI environment block to pass them into a script"
  task :parameter_template do |_t, args|
    param_template('command_parameters.yml', args.extras)
  end

  desc "Given a list of parameters generates a bash script to complete parsing and setting them up."
  task :script_template do |_t, args|
    param_template('script_base.sh', args.extras)
  end
end

task :default => :test
