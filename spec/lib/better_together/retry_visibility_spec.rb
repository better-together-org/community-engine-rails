# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'

RSpec.describe RetryVisibility do
  let(:file) { described_class::DIRECTORY.join("#{Process.pid}.jsonl") }
  let(:failed_attempts) { [StandardError.new('a'), StandardError.new('b')] }
  let(:example) do
    instance_double(RSpec::Core::Example, location: './spec/features/x_spec.rb:12', full_description: 'x does y',
                                          metadata: { type: :feature, js: true, retry_exceptions: failed_attempts },
                                          attempts: 2,
                                          exception: StandardError.new("boom\nmore"))
  end

  before { FileUtils.rm_f(file) }

  after { FileUtils.rm_f(file) }

  it 'records each failed attempt and each late pass, one JSON line each', :aggregate_failures do
    described_class.record('attempt_failed', example)
    described_class.record('passed_after_retry', example)

    entries = File.readlines(file).map { |line| JSON.parse(line) }
    expect(entries.map { |entry| entry['event'] }).to eq(%w[attempt_failed passed_after_retry])
    expect(entries.first).to include('location' => './spec/features/x_spec.rb:12', 'js' => true,
                                     'failed_attempts' => 2, 'error' => 'StandardError: boom')
  end

  it 'ignores a late-pass callback when no attempt actually failed (nested retry layers share one counter)' do
    clean = instance_double(RSpec::Core::Example, location: 'x', full_description: 'x', attempts: 1, exception: nil,
                                                  metadata: { type: :feature, js: true, retry_exceptions: [] })

    described_class.record('passed_after_retry', clean)

    expect(File.exist?(file)).to be(false)
  end

  it 'is wired into rspec-rebound' do
    expect([RSpec.configuration.retry_callback, RSpec.configuration.flaky_test_callback]).to all(respond_to(:call))
  end

  describe 'bin/ci-flaky-report' do
    let(:script) { BetterTogether::Engine.root.join('bin/ci-flaky-report').to_s }

    let(:run_report) { ->(dir, env = {}) { Open3.capture3(env, 'python3', script, dir) } }

    it 'says so when nothing was retried', :aggregate_failures do
      Dir.mktmpdir do |dir|
        out, _err, status = run_report.call(dir)

        expect(out).to include('every example passed on its first attempt')
        expect(status).to be_success
      end
    end

    it 'lists retried examples and fails only when CI_FAIL_ON_FLAKY is true', :aggregate_failures do
      Dir.mktmpdir do |dir|
        failed = { event: 'attempt_failed', location: './spec/a_spec.rb:3', description: 'a', error: 'E: x' }
        passed = failed.merge(event: 'passed_after_retry', error: nil)
        File.write(File.join(dir, '1.jsonl'), "#{JSON.generate(failed)}\n#{JSON.generate(passed)}\n")

        out, _err, status = run_report.call(dir)
        expect(out).to include('1 passed only after a retry', './spec/a_spec.rb:3')
        expect(status).to be_success

        _out, _err, strict = run_report.call(dir, 'CI_FAIL_ON_FLAKY' => 'true')
        expect(strict).not_to be_success
      end
    end
  end
end
