# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReportsController, :as_platform_manager do
  let(:locale) { I18n.default_locale }

  before do
    fake_report_class = Class.new do
      # Provide a model_name so Rails form_with/form_for can render without ActiveRecord
      def self.model_name
        ActiveModel::Name.new(self, nil, 'LinkCheckerReport')
      end

      # Instances should also respond to model_name so form helpers that receive
      # a record (not the class) work correctly.
      def model_name
        self.class.model_name
      end

      # form helpers may check persisted? when rendering forms
      def persisted?
        false
      end

      # Instances should expose filters so form helpers like f.select can read values
      def filters
        {}
      end

      def self.order(*)
        []
      end

      def self.create_and_generate!(*_args)
        file = Struct.new(:attached?).new(false)
        Struct.new(:id, :persisted?, :report_file).new(SecureRandom.uuid, true, file)
      end

      def self.find(id)
        # default find used in download test will be stubbed further inside that example
        file = Struct.new(:attached?).new(false)
        Struct.new(:id, :report_file).new(id, file)
      end
    end

    stub_const('BetterTogether::Metrics::LinkCheckerReport', fake_report_class)
  end

  describe 'GET /:locale/.../metrics/link_checker_reports' do
    before do
      get better_together.metrics_link_checker_reports_path(locale:)
    end

    it 'renders index' do
      expect(response).to have_http_status(:ok)
    end

    it 'renders new' do
      get better_together.new_metrics_link_checker_report_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /:locale/.../metrics/link_checker_reports' do
    before do
      post better_together.metrics_link_checker_reports_path(locale:), params: {
        metrics_link_checker_report: {
          file_format: 'csv',
          filters: { from_date: '', to_date: '' }
        }
      }
    end

    it 'creates a report and redirects with valid params' do
      expect(response).to have_http_status(:found)
    end

    it 'follows the redirect and renders ok' do
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../metrics/link_checker_reports/:id/download' do
    let(:file_contents) { 'a,b\n1,2\n' }
    let(:file_struct) { Struct.new(:attached?, :filename, :content_type, :download, :byte_size) }
    let(:fake_file) { file_struct.new(true, 'report.csv', 'text/csv', file_contents, file_contents.bytesize) }
    let(:fake_report) { Struct.new(:id, :report_file, :created_at).new('fake-id', fake_file, Time.current) }

    before do
      allow(BetterTogether::Metrics::LinkCheckerReport).to receive(:find).with('fake-id').and_return(fake_report)
      allow(BetterTogether::Metrics::TrackDownloadJob).to receive(:perform_later)
      get better_together.download_metrics_link_checker_report_path(locale:, id: 'fake-id')
    end

    it 'enqueues TrackDownloadJob when file is attached' do
      expect(BetterTogether::Metrics::TrackDownloadJob).to have_received(:perform_later)
        .with(fake_report, 'report.csv', 'text/csv', kind_of(Integer), I18n.locale.to_s)
    end

    it 'sends the file when attached' do
      expect(response.header['Content-Disposition']).to include('attachment')
    end
  end
end
