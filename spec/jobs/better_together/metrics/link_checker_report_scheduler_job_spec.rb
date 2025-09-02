# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReportSchedulerJob do
  include ActiveJob::TestHelper

  let(:from_date) { Date.parse('2025-09-01') }
  let(:to_date) { Date.parse('2025-09-01') }

  before do
    allow(BetterTogether::Metrics::LinkCheckerReport).to receive(:create_and_generate!).and_return(
      instance_double(
        BetterTogether::Metrics::LinkCheckerReport,
        id: 1,
        report_file: instance_double(ActiveStorage::Attached::One, attached?: true)
      )
    )
  end

  it 'runs without error' do
    expect { described_class.perform_now(from_date: from_date, to_date: to_date) }.not_to raise_error
  end
end
