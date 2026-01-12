# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:disable Metrics/ModuleLength
  module Metrics
    RSpec.describe UserAccountReport do
      describe 'associations' do
        it { is_expected.to have_one_attached(:report_file) }
      end

      describe 'validations' do
        it { is_expected.to validate_inclusion_of(:file_format).in_array(%w[csv]) }
      end

      describe '#generate!' do
        let!(:confirmed_user) { create(:user, created_at: 3.days.ago, confirmed_at: 2.days.ago) }
        let!(:unconfirmed_user) { create(:user, created_at: 1.day.ago, confirmed_at: nil) }
        let!(:early_user) { create(:user, created_at: 5.days.ago, confirmed_at: 5.days.ago) }
        let(:report) { described_class.new(filters: { from_date: 6.days.ago.to_date, to_date: Date.current }) }

        it 'builds report data and saves the report' do
          expect { report.generate! }.to change(described_class, :count).by(1)
          expect(report.report_data).to be_present
          expect(report.report_data['summary']).to be_present
          expect(report.report_data['daily_stats']).to be_present
          expect(report.report_data['registration_sources']).to be_present
        end

        it 'enqueues the CSV generation job' do
          report.save!
          expect { report.generate! }.to have_enqueued_job(GenerateUserAccountReportJob).with(report.id)
        end
      end

      describe '#build_summary' do
        let!(:confirmed_user) { create(:user, created_at: 2.days.ago, confirmed_at: 1.day.ago) }
        let!(:unconfirmed_user) { create(:user, created_at: 1.day.ago, confirmed_at: nil) }
        let(:report) { described_class.new(filters: { from_date: 3.days.ago.to_date, to_date: Date.current }) }
        let(:summary) { report.send(:build_summary) }

        it 'calculates total accounts created' do
          expect(summary[:total_accounts_created]).to eq(2)
        end

        it 'calculates total accounts confirmed' do
          expect(summary[:total_accounts_confirmed]).to eq(1)
        end

        it 'calculates confirmation rate' do
          expect(summary[:confirmation_rate]).to eq(50.0)
        end

        context 'when no accounts exist' do
          before { User.destroy_all }

          it 'returns zero confirmation rate' do
            expect(summary[:confirmation_rate]).to eq(0)
          end
        end
      end

      describe '#build_daily_stats' do
        let!(:user_three_days_ago) { create(:user, created_at: 3.days.ago, confirmed_at: 3.days.ago) }
        let!(:user_two_days_ago) { create(:user, created_at: 2.days.ago, confirmed_at: nil) }
        let!(:user_one_day_ago) { create(:user, created_at: 1.day.ago, confirmed_at: 1.day.ago) }
        let(:report) { described_class.new(filters: { from_date: 4.days.ago.to_date, to_date: Date.current }) }
        let(:daily_stats) { report.send(:build_daily_stats) }

        it 'creates daily statistics for each day in range' do
          expect(daily_stats).to be_an(Array)
          expect(daily_stats.size).to be >= 3
        end

        it 'includes accounts created for each day' do
          day_with_user = daily_stats.find { |stat| stat[:date] == 3.days.ago.to_date.iso8601 }
          expect(day_with_user[:accounts_created]).to eq(1)
        end

        it 'includes accounts confirmed for each day' do
          day_with_confirmed = daily_stats.find { |stat| stat[:date] == 1.day.ago.to_date.iso8601 }
          expect(day_with_confirmed[:accounts_confirmed]).to eq(1)
        end
      end

      describe '#build_registration_sources' do
        let!(:open_reg_user) { create(:user) }
        let!(:invited_user) do
          invitation = create(:invitation, status: 'accepted')
          create(:user, email: invitation.invitee_email)
        end
        let!(:oauth_user) do
          user = create(:user)
          create(:person_platform_integration, person: user.person)
          user
        end
        let(:report) { described_class.new }
        let(:sources) { report.send(:build_registration_sources) }

        it 'counts open registration users' do
          expect(sources[:open_registration]).to be >= 1
        end

        it 'counts invitation users' do
          expect(sources[:invitation]).to eq(1)
        end

        it 'counts OAuth users' do
          expect(sources[:oauth]).to eq(1)
        end
      end

      describe '#parse_date_range' do
        context 'with explicit dates' do
          let(:report) { described_class.new(filters: { from_date: '2024-01-01', to_date: '2024-01-31' }) }
          let(:date_range) { report.send(:parse_date_range) }

          it 'parses from_date' do
            expect(date_range.begin.to_date).to eq(Date.parse('2024-01-01'))
          end

          it 'parses to_date' do
            expect(date_range.end.to_date).to eq(Date.parse('2024-01-31'))
          end
        end

        context 'without explicit dates' do
          let(:report) { described_class.new }
          let(:date_range) { report.send(:parse_date_range) }

          it 'defaults to last 30 days' do
            expect(date_range.begin.to_date).to eq(30.days.ago.to_date)
            expect(date_range.end.to_date).to eq(Date.current)
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
