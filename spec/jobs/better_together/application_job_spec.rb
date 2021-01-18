require 'rails_helper'

class MyJob < ::BetterTogether::ApplicationJob
  queue_as :urgent

  # rescue_from(ActiveRecord::NotFound) do
  #   retry_job wait: 5.minutes, queue: :default
  # end

  def perform(*args)
    MyService.call(*args)
  end
end

class MyService
  def self.call(*args)
  end
end

RSpec.describe MyJob, type: :job do
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(123) }

  it 'queues the job' do
    expect { job }
      .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'is in urgent queue' do
    expect(MyJob.new.queue_name).to eq('urgent')
  end

  it 'executes perform' do
    expect(MyService).to receive(:call).with(123)
    perform_enqueued_jobs { job }
  end

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
end

# As of RSpec 3.4.0 we now have #have_enqueued_job
# https://www.relishapp.com/rspec/rspec-rails/v/3-5/docs/matchers/have-enqueued-job-matcher
RSpec.describe MyJob, type: :job do
  subject(:job) { described_class.perform_later(key) }

  let(:key) { 123 }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(key)
      .on_queue("urgent")
  end
end