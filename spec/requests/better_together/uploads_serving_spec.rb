# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether upload serving' do
  let(:creator) { create(:better_together_user, :confirmed) }
  let(:privacy) { 'public' }
  let(:content_type) { 'application/pdf' }
  let(:filename) { 'report.pdf' }
  let(:body) { '%PDF-1.4 sample' }
  let(:upload) do
    create(:better_together_upload, creator: creator.person, privacy:).tap do |record|
      record.file.attach(io: StringIO.new(body), filename:, content_type:)
    end
  end
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    host! 'www.example.com'
  end

  describe 'GET inline' do
    it 'shows a public PDF to a guest in the browser', :aggregate_failures do
      get better_together.inline_file_path(upload, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('%PDF-1.4 sample')
      expect(response.headers['Content-Disposition']).to start_with('inline')
      expect(response.headers['Content-Type']).to start_with('application/pdf')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    context 'when the file could run scripts in the browser' do
      let(:content_type) { 'text/html' }
      let(:filename) { 'page.html' }
      let(:body) { '<html><script>alert(1)</script></html>' }

      it 'still sends it as an attachment' do
        get better_together.inline_file_path(upload, locale:)

        expect(response.headers['Content-Disposition']).to start_with('attachment')
      end
    end

    context 'when the upload is private' do
      let(:privacy) { 'private' }

      it 'does not serve it to a guest' do
        get better_together.inline_file_path(upload, locale:)

        expect(response.body).not_to include('%PDF')
      end

      it 'serves it to its creator without public caching', :aggregate_failures do
        sign_in creator
        get better_together.inline_file_path(upload, locale:)

        expect(response).to have_http_status(:ok)
        expect(response.headers['Cache-Control']).to include('no-store')
      end
    end
  end

  describe 'GET download' do
    it 'serves a public file to a guest as an attachment with public cache headers', :aggregate_failures do
      get better_together.download_file_path(upload, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to start_with('attachment')
      expect(response.headers['Content-Length']).to eq(upload.byte_size.to_s)
      expect(response.headers['Cache-Control']).to include('public', 'max-age=86400')
      expect(response.headers['ETag']).to be_present
    end

    it 'answers a conditional request with 304', :aggregate_failures do
      get better_together.download_file_path(upload, locale:)
      etag = response.headers['ETag']

      get better_together.download_file_path(upload, locale:), headers: { 'If-None-Match' => etag }

      expect(response).to have_http_status(:not_modified)
      expect(response.body).to be_empty
    end
  end

  describe 'locale-free short paths' do
    it 'views the file at /f/:id' do
      get better_together.short_file_path(upload)

      expect(response.headers['Content-Disposition']).to start_with('inline')
    end

    it 'downloads the file at /f/:id/download' do
      get better_together.short_file_download_path(upload)

      expect(response.headers['Content-Disposition']).to start_with('attachment')
    end
  end

  describe 'unknown files' do
    it 'returns not found' do
      get better_together.short_file_path(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'content security hold' do
    around do |example|
      original = BetterTogether.content_security
      config = ActiveSupport::OrderedOptions.new
      scanning = ActiveSupport::OrderedOptions.new
      scanning.merge!(enabled: true, engine: 'clamav', host: '127.0.0.1', port: 3310, timeout: 1,
                      max_stream_bytes: 5.megabytes, fail_mode: 'hold_until_clean', enabled_surfaces: ['uploads'])
      config.malware_scanning = scanning
      BetterTogether.content_security = config
      example.run
    ensure
      BetterTogether.content_security = original
    end

    it 'tells the visitor the file is still being checked', :aggregate_failures do
      BetterTogether::ContentSecurity::AttachmentEnrollment.sync_attachment!(
        record: upload, attachment_name: :file, surface: :uploads
      )

      get better_together.short_file_path(upload), headers: { 'HTTP_REFERER' => 'http://www.example.com/en' }

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to eq(I18n.t('resources.download_held'))
    end
  end
end
