# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::MetricsJob do
  it 'uses the metrics queue' do
    expect(described_class.queue_name).to eq('metrics')
  end

  it 'inherits from ApplicationJob' do
    expect(described_class.superclass).to eq(BetterTogether::ApplicationJob)
  end
end
