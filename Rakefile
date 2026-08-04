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

def changelog_top_version
  line = File.readlines('CHANGELOG.md').find { |l| l.start_with?('## ') }
  raise 'CHANGELOG.md has no version headers' unless line

  line.delete_prefix('## ').strip
end

def ensure_changelog_covers_promotion!
  published = registry_version
  documented = changelog_top_version

  return if Gem::Version.new(documented) > Gem::Version.new(published)

  $stderr.puts <<~MSG
    CHANGELOG.md's top entry is ##{documented}, but #{ORGANIZATION}/#{ORB_NAME}@#{published} is already published.
    Add a CHANGELOG.md entry for the version this promote will create before running rake promote:* -- a promote without one leaves the registry undocumented.
  MSG
  exit 1
end

def promote(label:, version:, verbose: false)
  ensure_changelog_covers_promotion!
  sh "circleci orb publish promote #{ORGANIZATION}/#{ORB_NAME}@#{label} #{version}", verbose: verbose
end

desc 'Validate the orb'
task :validate do
  with_packed_orb do |orbfile|
    sh "circleci orb validate #{orbfile}", verbose: false
  end
end

desc 'Run shellcheck on all scripts'
task :shellcheck do
  sh 'shellcheck src/scripts/*'
end

desc 'Validate the orb and run shellcheck on all scripts'
task :test => [:validate, :shellcheck]

desc 'Publish the orb to the dev:alpha tag'
task :publish do
  with_packed_orb do |orbfile|
    sh "circleci orb publish #{orbfile} #{ORGANIZATION}/#{ORB_NAME}@dev:alpha", verbose: false
  end
end

desc 'Promote the version at dev:alpha to production and bump the patch release'
namespace :promote do
  %w[patch minor major].each do |version|
    desc "Promote dev:alpha to production and bump the #{version} in version"
    task version.to_sym do
      promote(label: 'dev:alpha', version: version)
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
