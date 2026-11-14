# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::RichTextInternalLinkCheckerQueueJob do
  subject(:job) { described_class.new }

  it 'inherits from RichTextLinkCheckerQueueJob' do
    expect(described_class.superclass).to eq(BetterTogether::Metrics::RichTextLinkCheckerQueueJob)
  end

  it 'uses InternalLinkCheckerJob as the child job class' do
    expect(job.send(:child_job_class)).to eq(BetterTogether::Metrics::InternalLinkCheckerJob)
  end

  it 'returns a 5-minute queue delay' do
    expect(job.send(:queue_delay)).to eq(5.minutes)
  end
end
