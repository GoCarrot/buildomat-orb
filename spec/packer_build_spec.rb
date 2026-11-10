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

require 'yaml'

RSpec.describe 'src/commands/packer-build.yml' do
  command = YAML.safe_load_file(File.expand_path('../src/commands/packer-build.yml', __dir__))
  build_env = command['steps'].filter_map { |s| s['run'] }.find { |r| r['name'] == 'Packer Build' }['environment']

  it 'retries lost ssh connections' do
    expect(build_env['ANSIBLE_SSH_RETRIES']).to eq('5')
  end

  it 'pins the python interpreter so discovery cannot fall back to /usr/bin/python' do
    expect(build_env['ANSIBLE_PYTHON_INTERPRETER']).to eq('/usr/bin/python3')
  end
end
