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

module ChangelogGate
  class MissingVersionHeader < StandardError; end

  # Parses the first `## x.y.z` header out of a CHANGELOG.md's contents.
  def self.top_version(changelog_text)
    line = changelog_text.each_line.find { |l| l.start_with?('## ') }
    raise MissingVersionHeader, 'CHANGELOG has no version headers' unless line

    line.delete_prefix('## ').strip
  end

  # True when the CHANGELOG's top entry is titled exactly `expected_version`.
  def self.documents_version?(changelog_text, expected_version)
    top_version(changelog_text) == expected_version
  end

  # True when the CHANGELOG's top entry is a newer semver than `floor_version`.
  def self.documents_newer_than?(changelog_text, floor_version)
    Gem::Version.new(top_version(changelog_text)) > Gem::Version.new(floor_version)
  end

  class UnrecognizedPromoteOutput < StandardError; end

  # Pulls the published version out of `circleci orb publish promote`'s
  # stdout, e.g. "Orb `teak/buildomat@dev:alpha` was promoted to
  # `teak/buildomat@0.1.11`." Raises rather than returning nil on a format
  # we don't recognize, so an unparseable output fails the gate instead of
  # silently skipping it.
  def self.parse_promoted_version(promote_output, organization, orb_name)
    match = promote_output.match(/was promoted to `#{Regexp.escape("#{organization}/#{orb_name}")}@(\S+?)`/)
    raise UnrecognizedPromoteOutput, "could not find a promoted version in:\n#{promote_output}" unless match

    match[1]
  end
end
