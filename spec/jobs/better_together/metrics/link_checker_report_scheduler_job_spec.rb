# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReportSchedulerJob do
  include ActiveJob::TestHelper

  let(:from_date) { Date.parse('2025-09-01') }
  let(:to_date) { Date.parse('2025-09-01') }

  before do
    fake_report_class = Class.new do
      def self.create_and_generate!(_opts = {})
        file_struct = Struct.new(:attached?)
        report_file = file_struct.new(true)
        Struct.new(:id, :report_file).new(1, report_file)
      end
    end

    stub_const('BetterTogether::Metrics::LinkCheckerReport', fake_report_class)
  end

  it 'runs without error' do
    expect { described_class.perform_now(from_date: from_date, to_date: to_date) }.not_to raise_error
  end
end
