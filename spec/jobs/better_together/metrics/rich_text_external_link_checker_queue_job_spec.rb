# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::RichTextExternalLinkCheckerQueueJob do
  subject(:job) { described_class.new }

  it 'inherits from RichTextLinkCheckerQueueJob' do
    expect(described_class.superclass).to eq(BetterTogether::Metrics::RichTextLinkCheckerQueueJob)
  end

  it 'uses ExternalLinkCheckerJob as the child job class' do
    expect(job.send(:child_job_class)).to eq(BetterTogether::Metrics::ExternalLinkCheckerJob)
  end
end
