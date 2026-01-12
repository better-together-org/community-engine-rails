# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Metrics
    RSpec.describe GenerateUserAccountReportJob do
      let(:report) { create(:user_account_report) }

      before do
        # Build report data
        report.report_data = {
          'summary' => {
            'total_accounts_created' => 10,
            'total_accounts_confirmed' => 8,
            'confirmation_rate' => 80.0
          },
          'daily_stats' => [
            { 'date' => '2024-01-01', 'accounts_created' => 5, 'accounts_confirmed' => 4 },
            { 'date' => '2024-01-02', 'accounts_created' => 5, 'accounts_confirmed' => 4 }
          ],
          'registration_sources' => {
            'open_registration' => 6,
            'invitation' => 3,
            'oauth' => 1
          }
        }
        report.save!
      end

      describe '#perform' do
        it 'generates a CSV file' do
          described_class.new.perform(report.id)
          expect(report.reload.report_file).to be_attached
        end

        it 'sets the correct filename' do
          described_class.new.perform(report.id)
          filename = report.reload.report_file.filename.to_s
          expect(filename).to match(/user_account_report_.*\.csv/)
        end

        it 'includes summary data in CSV' do
          described_class.new.perform(report.id)
          csv_content = report.reload.report_file.download
          expect(csv_content).to include('Summary')
          expect(csv_content).to include('Total Accounts Created,10')
          expect(csv_content).to include('Total Accounts Confirmed,8')
          expect(csv_content).to include('Overall Confirmation Rate (%),80.0')
        end

        it 'includes daily stats in CSV' do
          described_class.new.perform(report.id)
          csv_content = report.reload.report_file.download
          expect(csv_content).to include('Date,Accounts Created,Accounts Confirmed')
          expect(csv_content).to include('2024-01-01,5,4')
          expect(csv_content).to include('2024-01-02,5,4')
        end

        it 'includes registration sources in CSV' do
          described_class.new.perform(report.id)
          csv_content = report.reload.report_file.download
          expect(csv_content).to include('Registration Sources')
          expect(csv_content).to include('Open Registration,6')
          expect(csv_content).to include('Via Invitation,3')
          expect(csv_content).to include('Via OAuth,1')
        end
      end

      describe 'job queuing' do
        it 'is in the metrics queue' do
          expect(described_class.new.queue_name).to eq('metrics')
        end
      end
    end
  end
end
