# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::BillingReport do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing report data'

  let(:creator) { create(:better_together_person) }

  it 'keeps the filters and the figures it was made with', :aggregate_failures do
    order = paid_order(paid_at: 2.days.ago)
    line_for(order, cents: 5000)
    pay(order)

    report = described_class.create_and_generate!(creator:, platform: host_platform, owner: 'platform', interval: 'quarter')

    expect(report.filter('interval')).to eq('quarter')
    expect(report.report_data['summaries'].first['currency']).to eq('CAD')
    expect(report.report_data['summaries'].first['exempt_cents']).to eq(5000)
  end

  it 'queues the file job' do
    expect { described_class.create_and_generate!(creator:, platform: host_platform) }
      .to have_enqueued_job(BetterTogether::Metrics::GenerateBillingReportJob)
  end

  it 'only accepts csv' do
    report = described_class.new(platform: host_platform, filters: { 'owner' => 'all' }, file_format: 'pdf')

    expect(report).not_to be_valid
  end
end
