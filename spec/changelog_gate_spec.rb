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

require_relative '../lib/changelog_gate'

RSpec.describe ChangelogGate do
  describe '.top_version' do
    it 'parses the first header' do
      text = "## 0.1.11\n\nBUG FIXES:\n\n* stuff\n\n## 0.1.10\n"
      expect(described_class.top_version(text)).to eq('0.1.11')
    end

    it 'raises when there is no header' do
      expect { described_class.top_version("no headers here\n") }
        .to raise_error(ChangelogGate::MissingVersionHeader)
    end
  end

  describe '.documents_version?' do
    it 'matches exactly' do
      text = "## 0.1.11\n"
      expect(described_class.documents_version?(text, '0.1.11')).to be(true)
      expect(described_class.documents_version?(text, '0.1.10')).to be(false)
    end

    it 'rejects a newer but wrong title' do
      text = "## 0.2.0\n"
      expect(described_class.documents_version?(text, '0.1.11')).to be(false)
    end
  end

  describe '.documents_newer_than?' do
    it 'passes for a genuinely newer entry' do
      expect(described_class.documents_newer_than?("## 0.1.11\n", '0.1.10')).to be(true)
    end

    it 'fails when the top entry is already published' do
      expect(described_class.documents_newer_than?("## 0.1.10\n", '0.1.10')).to be(false)
    end

    it 'fails when the top entry is stale' do
      expect(described_class.documents_newer_than?("## 0.1.9\n", '0.1.10')).to be(false)
    end

    it 'raises on a non-semver header instead of a raw Gem::Version error' do
      expect { described_class.documents_newer_than?("## Unreleased\n", '0.1.10') }
        .to raise_error(ChangelogGate::MissingVersionHeader)
    end
  end

  describe '.parse_promoted_version' do
    it 'extracts the published version' do
      output = "Orb `teak/buildomat@dev:alpha` was promoted to `teak/buildomat@0.1.11`.\n"
      expect(described_class.parse_promoted_version(output, 'teak', 'buildomat')).to eq('0.1.11')
    end

    # Fail closed: an output format we don't recognize must raise, not be
    # treated as "no version, so nothing to check."
    it 'raises on unrecognized output' do
      expect { described_class.parse_promoted_version("something unexpected happened\n", 'teak', 'buildomat') }
        .to raise_error(ChangelogGate::UnrecognizedPromoteOutput)
    end

    it 'raises when the promoted orb is a different one' do
      output = "Orb `teak/other-orb@dev:alpha` was promoted to `teak/other-orb@1.0.0`.\n"
      expect { described_class.parse_promoted_version(output, 'teak', 'buildomat') }
        .to raise_error(ChangelogGate::UnrecognizedPromoteOutput)
    end
  end
end
