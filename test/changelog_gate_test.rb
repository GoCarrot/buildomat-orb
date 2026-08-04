# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/changelog_gate'

class ChangelogGateTest < Minitest::Test
  def test_top_version_parses_the_first_header
    text = "## 0.1.11\n\nBUG FIXES:\n\n* stuff\n\n## 0.1.10\n"
    assert_equal '0.1.11', ChangelogGate.top_version(text)
  end

  def test_top_version_raises_when_there_is_no_header
    assert_raises(ChangelogGate::MissingVersionHeader) do
      ChangelogGate.top_version("no headers here\n")
    end
  end

  def test_documents_version_matches_exactly
    text = "## 0.1.11\n"
    assert ChangelogGate.documents_version?(text, '0.1.11')
    refute ChangelogGate.documents_version?(text, '0.1.10')
  end

  # This is the C-1275 failure mode: a CHANGELOG entry titled for a version
  # that was never the one actually published.
  def test_documents_version_rejects_a_newer_but_wrong_title
    text = "## 0.2.0\n"
    refute ChangelogGate.documents_version?(text, '0.1.11')
  end

  def test_documents_newer_than_passes_for_a_genuinely_newer_entry
    assert ChangelogGate.documents_newer_than?("## 0.1.11\n", '0.1.10')
  end

  def test_documents_newer_than_fails_when_top_entry_is_already_published
    refute ChangelogGate.documents_newer_than?("## 0.1.10\n", '0.1.10')
  end

  def test_documents_newer_than_fails_when_top_entry_is_stale
    refute ChangelogGate.documents_newer_than?("## 0.1.9\n", '0.1.10')
  end

  def test_parse_promoted_version_extracts_the_published_version
    output = "Orb `teak/buildomat@dev:alpha` was promoted to `teak/buildomat@0.1.11`.\n"
    assert_equal '0.1.11', ChangelogGate.parse_promoted_version(output, 'teak', 'buildomat')
  end

  # Fail closed: an output format we don't recognize must raise, not be
  # treated as "no version, so nothing to check."
  def test_parse_promoted_version_raises_on_unrecognized_output
    assert_raises(ChangelogGate::UnrecognizedPromoteOutput) do
      ChangelogGate.parse_promoted_version("something unexpected happened\n", 'teak', 'buildomat')
    end
  end
end
