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

  describe '.next_version' do
    it 'bumps each segment and zeroes the ones below it' do
      expect(described_class.next_version('0.1.12', 'patch')).to eq('0.1.13')
      expect(described_class.next_version('0.1.12', 'minor')).to eq('0.2.0')
      expect(described_class.next_version('0.1.12', 'major')).to eq('1.0.0')
    end

    it 'raises on a bump the orb CLI does not offer' do
      expect { described_class.next_version('0.1.12', 'mega') }.to raise_error(ArgumentError, /mega/)
    end
  end

  describe '.documents_next_version?' do
    it 'passes when the top entry is exactly the version the bump will publish' do
      expect(described_class.documents_next_version?("## 0.1.13\n", '0.1.12', 'patch')).to be(true)
      expect(described_class.documents_next_version?("## 0.2.0\n", '0.1.12', 'minor')).to be(true)
    end

    it 'fails when the top entry is already published' do
      expect(described_class.documents_next_version?("## 0.1.12\n", '0.1.12', 'patch')).to be(false)
    end

    it 'fails when the top entry is stale' do
      expect(described_class.documents_next_version?("## 0.1.9\n", '0.1.12', 'patch')).to be(false)
    end

    it 'fails when the entry is newer than the bump will produce' do
      expect(described_class.documents_next_version?("## 0.2.0\n", '0.1.12', 'patch')).to be(false)
    end

    it 'fails on a header that is not a version' do
      expect(described_class.documents_next_version?("## Unreleased\n", '0.1.12', 'patch')).to be(false)
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
