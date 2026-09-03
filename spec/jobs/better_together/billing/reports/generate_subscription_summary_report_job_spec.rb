# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    module Reports
      RSpec.describe GenerateSubscriptionSummaryReportJob do
        subject(:job) { described_class.new }

        let(:report) do
          create('better_together/billing/reports/subscription_summary_report', :with_data)
        end

        it 'attaches a CSV file to the report' do
          described_class.perform_now(report.id)
          expect(report.reload.report_file).to be_attached
        end

        it 'generates a file with the correct content type' do
          described_class.perform_now(report.id)
          expect(report.reload.report_file.content_type).to eq('text/csv')
        end

        it 'generates a filename containing the date range' do
          described_class.perform_now(report.id)
          filename = report.reload.report_file.filename.to_s
          expect(filename).to include('billing_subscription_summary_')
        end
      end
    end
  end
end
