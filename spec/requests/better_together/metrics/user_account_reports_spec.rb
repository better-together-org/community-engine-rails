# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Metrics
    RSpec.describe UserAccountReportsController, :as_platform_manager do
      describe 'GET /metrics/user_account_reports' do
        let!(:first_report) { create(:user_account_report, :with_data) }
        let!(:second_report) { create(:user_account_report, :with_data) }

        it 'returns a successful response' do
          get metrics_user_account_reports_path(locale: I18n.default_locale)
          expect(response).to be_successful
        end

        it 'renders the index partial for Turbo Frame requests' do
          get metrics_user_account_reports_path(locale: I18n.default_locale), headers: { 'Turbo-Frame' => 'user_account_reports' }
          expect(response).to be_successful
        end
      end

      describe 'GET /metrics/user_account_reports/new' do
        it 'returns a successful response' do
          get new_metrics_user_account_report_path(locale: I18n.default_locale)
          expect(response).to be_successful
        end
      end

      describe 'POST /metrics/user_account_reports' do
        let(:valid_params) do
          {
            metrics_user_account_report: {
              file_format: 'csv',
              filters: {
                from_date: 7.days.ago.to_date.to_s,
                to_date: Date.current.to_s
              }
            }
          }
        end

        it 'creates a new report' do
          expect do
            post metrics_user_account_reports_path(locale: I18n.default_locale), params: valid_params
          end.to change(UserAccountReport, :count).by(1)
        end

        it 'redirects to the index page' do
          post metrics_user_account_reports_path(locale: I18n.default_locale), params: valid_params
          expect(response).to redirect_to(metrics_user_account_reports_path(locale: I18n.default_locale))
        end

        it 'sets a success flash message' do
          post metrics_user_account_reports_path(locale: I18n.default_locale), params: valid_params
          follow_redirect!
          expect(flash[:notice]).to be_present
        end

        it 'enqueues the CSV generation job' do
          expect do
            post metrics_user_account_reports_path(locale: I18n.default_locale), params: valid_params
          end.to have_enqueued_job(GenerateUserAccountReportJob)
        end
      end

      describe 'GET /metrics/user_account_reports/:id/download' do
        let(:report) { create(:user_account_report, :with_data, :with_file) }

        it 'sends the file data' do
          get download_metrics_user_account_report_path(report, locale: I18n.default_locale)
          expect(response).to be_successful
          expect(response.content_type).to eq('text/csv')
        end

        it 'tracks the download' do
          expect do
            get download_metrics_user_account_report_path(report, locale: I18n.default_locale)
          end.to have_enqueued_job(BetterTogether::Metrics::TrackDownloadJob)
        end

        context 'when file is not attached' do
          let(:report_without_file) { create(:user_account_report, :with_data) }

          it 'redirects back with an alert' do
            get download_metrics_user_account_report_path(report_without_file, locale: I18n.default_locale)
            expect(response).to redirect_to(metrics_user_account_reports_path(locale: I18n.default_locale))
            follow_redirect!
            expect(flash[:alert]).to be_present
          end
        end
      end
    end
  end
end
