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

require 'shellwords'
require 'timeout'

module ScriptHarness
  SCRIPTS_DIR = File.expand_path('../src/scripts', __dir__)
  DEFAULT_TIMEOUT = 5

  Result = Struct.new(:stdout, :stderr, :status)

  class TimeoutError < StandardError; end

  def self.source(script, bash_code, env: {}, timeout: DEFAULT_TIMEOUT, chdir: nil)
    script_path = File.join(SCRIPTS_DIR, script)
    raise ArgumentError, "No such script: #{script_path}" unless File.file?(script_path)

    full_command = "source #{script_path.shellescape}\n#{bash_code}"
    run(['bash', '-e', '-o', 'pipefail', '-c', full_command], env: env, timeout: timeout, chdir: chdir)
  end

  def self.run(cmd, env:, timeout:, chdir: nil)
    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe
    spawn_opts = { out: stdout_w, err: stderr_w, pgroup: true }
    spawn_opts[:chdir] = chdir if chdir
    pid = Process.spawn(env, *cmd, **spawn_opts)
    stdout_w.close
    stderr_w.close

    status = wait_with_timeout(pid, timeout)
    Result.new(stdout_r.read, stderr_r.read, status)
  ensure
    stdout_r&.close
    stderr_r&.close
  end
  private_class_method :run

  def self.wait_with_timeout(pid, timeout)
    Timeout.timeout(timeout, TimeoutError) { Process.wait2(pid).last }
  rescue TimeoutError
    begin
      Process.kill('KILL', -pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
    end
    raise TimeoutError, "script hung past #{timeout}s -- did it lose its source guard?"
  end
  private_class_method :wait_with_timeout
end
