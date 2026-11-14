# frozen_string_literal: true

# rspec-rebound retries :feature and :js examples (up to 3 retries) and then reports only the final result,
# so an example that passed on attempt 3 looks identical to one that passed first time. These callbacks record
# each failed attempt and each late pass, one JSON line each in tmp/flaky/<pid>.jsonl, for bin/ci-flaky-report.
# (A reporter listener does not work here: parallel_rspec workers do not receive reporter events.)
# It changes no behaviour.
module RetryVisibility
  DIRECTORY = BetterTogether::Engine.root.join('tmp/flaky')

  class << self
    # event: 'attempt_failed' (a retry follows) or 'passed_after_retry'.
    # CE nests several run_with_retry layers (global, :feature, :js) around one example and they share one
    # attempts counter, so rspec-rebound's flaky callback also fires for examples that passed first time.
    # Only an example with a recorded failed attempt (metadata[:retry_exceptions]) really needed a retry.
    def record(event, example)
      return if event == 'passed_after_retry' && Array(example.metadata[:retry_exceptions]).empty?

      FileUtils.mkdir_p(DIRECTORY)
      File.open(DIRECTORY.join("#{Process.pid}.jsonl"), 'a') { |file| file.puts(JSON.generate(entry(event, example))) }
    rescue StandardError => e
      warn "[retry-visibility] could not record #{example.location}: #{e.class}: #{e.message}"
    end

    private

    def entry(event, example)
      {
        event:, location: example.location, description: example.full_description.to_s[0, 160],
        type: example.metadata[:type], js: example.metadata[:js] ? true : false,
        failed_attempts: Array(example.metadata[:retry_exceptions]).size, error: describe_error(example.exception)
      }
    end

    def describe_error(error)
      return unless error

      "#{error.class}: #{error.message.to_s.lines.first&.strip}"[0, 220]
    end
  end
end

RSpec.configure do |config|
  config.retry_callback = ->(example) { RetryVisibility.record('attempt_failed', example) }
  config.flaky_test_callback = ->(example) { RetryVisibility.record('passed_after_retry', example) }
end
