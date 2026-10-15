# frozen_string_literal: true

require 'rails_helper'

# Test job class for ApplicationJob specs.
class MyJob < BetterTogether::ApplicationJob
  queue_as :urgent

  class Service
    def self.call(*args); end
  end

  # rescue_from(ActiveRecord::NotFound) do
  #   retry_job wait: 5.minutes, queue: :default
  # end

  def perform(*)
    Service.call(*)
  end
end

# rubocop:todo RSpec/RepeatedExampleGroupDescription
RSpec.describe MyJob do # rubocop:todo RSpec/MultipleDescribes, RSpec/RepeatedExampleGroupDescription
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(123) }

  # it 'handles no results error' do
  #   allow(MyService).to receive(:call).and_raise(ActiveRecord::NotFound)

  #   perform_enqueued_jobs do
  #     expect_any_instance_of(MyJob)
  #       .to receive(:retry_job).with(wait: 10.minutes, queue: :default)

  #     job
  #   end
  # end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'queues the job' do
    expect { job }
      .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'is in urgent queue' do
    expect(described_class.new.queue_name).to eq('urgent')
  end

  it 'executes perform' do
    expect(MyJob::Service).to receive(:call).with(123)
    perform_enqueued_jobs { job }
  end
end
# rubocop:enable RSpec/RepeatedExampleGroupDescription

# As of RSpec 3.4.0 we now have #have_enqueued_job
# https://www.relishapp.com/rspec/rspec-rails/v/3-5/docs/matchers/have-enqueued-job-matcher
RSpec.describe MyJob do # rubocop:todo RSpec/RepeatedExampleGroupDescription
  subject(:job) { described_class.perform_later(key) }

  let(:key) { 123 }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(key)
      .on_queue('urgent')
  end
end

# Several real jobs declare their own retry_on StandardError/discard_on. That's
# implemented via ActiveJob's own rescue_from under the hood, so this verifies
# ApplicationJob's error-reporting hook (around_perform, not rescue_from) doesn't
# shadow a subclass's own retry_on for the same exception class.
class RetryOnPrecedenceTestJob < BetterTogether::ApplicationJob
  retry_on StandardError, wait: 1.second, attempts: 3

  cattr_accessor :call_count, default: 0

  def perform
    self.class.call_count += 1
    raise 'boom' if self.class.call_count == 1
  end
end

RSpec.describe RetryOnPrecedenceTestJob do
  include ActiveJob::TestHelper

  after { described_class.call_count = 0 }

  it 'still schedules and runs the subclass retry_on retry instead of being intercepted' do
    expect(BetterTogether).not_to receive(:report_error)

    perform_enqueued_jobs { described_class.perform_later }

    expect(described_class.call_count).to eq(2)
  end
end

RSpec.describe BetterTogether::ApplicationJob do
  let(:error) { StandardError.new('boom') }

  before do
    allow(MyJob::Service).to receive(:call).and_raise(error)
  end

  context 'when Rails.env.production?' do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it 're-raises the exception and reports it via BetterTogether.report_error' do
      expect(BetterTogether).to receive(:report_error).with(
        error,
        context: hash_including(job_class: 'MyJob')
      )

      expect { MyJob.perform_now(123) }.to raise_error(error)
    end

    it 'does not swallow the exception when error reporting itself fails' do
      allow(BetterTogether).to receive(:report_error).and_raise('reporter down')

      expect { MyJob.perform_now(123) }.to raise_error(error)
    end
  end

  context 'when not in production' do
    it 're-raises the exception without calling BetterTogether.report_error' do
      expect(BetterTogether).not_to receive(:report_error)

      expect { MyJob.perform_now(123) }.to raise_error(error)
    end
  end
end
