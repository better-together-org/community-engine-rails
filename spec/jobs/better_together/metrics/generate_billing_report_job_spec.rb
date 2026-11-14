# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::GenerateBillingReportJob do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing report data'

  let(:creator) { create(:better_together_person) }
  let(:report) { BetterTogether::Metrics::BillingReport.create_and_generate!(creator:, platform: host_platform) }

  it 'attaches a CSV file', :aggregate_failures do
    described_class.perform_now(report.id)

    expect(report.reload.report_file).to be_attached
    expect(report.report_file.content_type).to eq('text/csv')
  end

  it 'tells the creator the file is ready, naming the row' do
    expect { described_class.perform_now(report.id) }
      .to have_broadcasted_to(creator).from_channel(BetterTogether::Metrics::UserAccountReportsChannel)
                                      .with(a_hash_including(row_id: "billing_report_#{report.id}", file_ready: true))
  end
end
