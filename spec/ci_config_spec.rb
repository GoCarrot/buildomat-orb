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

require 'json'
require 'yaml'

# The CI configs can't be run locally, and `circleci config validate` can't see
# these cross-file invariants.
RSpec.describe '.circleci configs' do
  root = File.expand_path('..', __dir__)
  config = YAML.safe_load_file(File.join(root, '.circleci/config.yml'))
  promote = YAML.safe_load_file(File.join(root, '.circleci/promote.yml'))

  def pin(cfg)
    cfg.dig('commands', 'install-cli', 'steps', 0, 'circleci-cli/install', 'version')
  end

  it 'pins the same circleci CLI in both files' do
    expect(pin(config)).to match(/\Av\d/)
    expect(pin(promote)).to eq(pin(config))
  end

  it 'runs notify alongside the hold: it requires nothing and nothing requires it' do
    jobs = promote.dig('workflows', 'promote', 'jobs').to_h { |j| j.first }

    expect(jobs['notify']).not_to have_key('requires')
    expect(jobs['hold']).not_to have_key('requires')
    expect(jobs.values.flat_map { |j| j['requires'] || [] }).not_to include('notify')
  end

  it 'declares exactly the parameters script/ci-promote-gate writes' do
    expect(promote['parameters'].keys).to match_array(%w[bump orb-version])
  end
end
