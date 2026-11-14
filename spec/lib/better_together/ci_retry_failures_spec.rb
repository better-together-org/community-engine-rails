# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'

# Drives bin/ci-retry-failures with a stub runner standing in for `bundle exec rspec`.
RSpec.describe 'bin/ci-retry-failures' do # rubocop:disable RSpec/DescribeClass
  let(:script) { Rails.root.join('../../bin/ci-retry-failures').to_s }
  let(:dir) { Pathname.new(Dir.mktmpdir) }
  let(:results_path) { dir.join('results.json') }
  let(:flaky_dir) { dir.join('flaky') }
  # Stub runner: reads the pass list for the current round from a scenario file ("passes" per round).
  let(:stub_runner) do
    path = dir.join('stub_runner.rb')
    path.write(<<~RUBY)
      require 'json'
      out = ARGV[ARGV.index('--out') + 1]
      ids = ARGV.drop(ARGV.index('--no-color') + 1)
      scenario = JSON.parse(File.read(ENV.fetch('STUB_SCENARIO')))
      round = File.exist?(ENV.fetch('STUB_COUNTER')) ? File.read(ENV.fetch('STUB_COUNTER')).to_i + 1 : 1
      File.write(ENV.fetch('STUB_COUNTER'), round.to_s)
      exit 1 if scenario['crash']
      passing = scenario['passes'][round - 1] || []
      examples = ids.map { |id| { id: id, status: passing.include?(id) ? 'passed' : 'failed', file_path: id, line_number: 1, full_description: id } }
      File.write(out, JSON.dump(examples: examples, summary: { example_count: ids.size, errors_outside_of_examples_count: 0 }))
    RUBY
    path.to_s
  end

  def example_hash(id, status)
    { id: id, status: status, file_path: "./spec/#{id}_spec.rb", line_number: 7, full_description: "desc #{id}",
      exception: (status == 'failed' ? { class: 'Boom', message: "bad #{id}" } : nil) }
  end

  def write_results(statuses, summary = {})
    examples = statuses.map { |id, status| example_hash(id, status) }
    failures = statuses.values.count('failed')
    results_path.write(JSON.dump(
                         examples: examples,
                         summary: { example_count: examples.size, failure_count: failures, pending_count: 0,
                                    errors_outside_of_examples_count: 0 }.merge(summary),
                         summary_line: "#{examples.size} examples, #{failures} failures, 0 pending"
                       ))
  end

  def runner_env
    { 'CI_RETRY_COMMAND' => "ruby #{stub_runner}", 'STUB_SCENARIO' => dir.join('scenario.json').to_s,
      'STUB_COUNTER' => dir.join('counter').to_s }
  end

  def run_script(scenario: {}, args: [])
    dir.join('scenario.json').write(JSON.dump(scenario))
    paths = { '--results' => results_path, '--retry-dir' => dir.join('retry'), '--flaky-dir' => flaky_dir }
    Open3.capture2e(runner_env, script, *paths.flat_map { |flag, path| [flag, path.to_s] }, *args)
  end

  def rounds_run
    dir.join('counter').exist? ? dir.join('counter').read.to_i : 0
  end

  def saved
    JSON.parse(results_path.read)
  end

  after { FileUtils.rm_rf(dir) }

  it 'flips late passes, recomputes the summary and logs them for the flaky report', :aggregate_failures do
    write_results({ 'a' => 'passed', 'b' => 'failed', 'c' => 'failed' })

    output, status = run_script(scenario: { passes: [%w[b c]] })

    expect(status.exitstatus).to eq(0)
    expect(output).to include('2 passed after retry')
    expect(saved['summary']['failure_count']).to eq(0)
    expect(saved['summary_line']).to eq('3 examples, 0 failures, 0 pending')
    events = flaky_dir.glob('retry-*.jsonl').flat_map { |f| f.readlines.map { |line| JSON.parse(line) } }
    expect(events.map { |e| e['event'] }.uniq).to eq(['passed_after_retry'])
    expect(events.first).to include('location' => './spec/b_spec.rb:7', 'error' => 'Boom: bad b')
  end

  it 'keeps retrying only what still fails, up to the limit', :aggregate_failures do
    write_results({ 'a' => 'failed', 'b' => 'failed', 'c' => 'failed' })

    _output, status = run_script(scenario: { passes: [%w[a], %w[b], %w[c]] }, args: %w[--retries 3])

    expect([status.exitstatus, rounds_run]).to eq([0, 3])
    expect(saved['summary']['failure_count']).to eq(0)
  end

  it 'stops early when a retry fails the identical set (deterministic failure)', :aggregate_failures do
    write_results({ 'a' => 'failed' })

    output, status = run_script(scenario: { passes: [] })

    expect(status.exitstatus).to eq(1)
    expect(rounds_run).to eq(1)
    expect(output).to include('deterministic')
    expect(saved['summary']['failure_count']).to eq(1)
  end

  it 'does not retry load errors, zero examples or missing results', :aggregate_failures do
    write_results({ 'a' => 'failed' }, { errors_outside_of_examples_count: 1 })
    _output, status = run_script
    expect([status.exitstatus, rounds_run]).to eq([1, 0])

    results_path.delete
    _output, status = run_script
    expect([status.exitstatus, rounds_run]).to eq([1, 0])
  end

  it 'does not retry when too many examples failed (systemic, not flaky)', :aggregate_failures do
    write_results({ 'a' => 'failed', 'b' => 'failed', 'c' => 'failed' })

    output, status = run_script(args: %w[--max-failed 2])

    expect([status.exitstatus, rounds_run]).to eq([1, 0])
    expect(output).to include('exceeds --max-failed=2')
  end

  it 'leaves the results untouched when the runner produces nothing usable', :aggregate_failures do
    write_results({ 'a' => 'failed' })

    _output, status = run_script(scenario: { crash: true })

    expect(status.exitstatus).to eq(1)
    expect(saved['summary']['failure_count']).to eq(1)
  end
end
