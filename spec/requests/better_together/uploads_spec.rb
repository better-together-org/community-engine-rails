# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Uploads' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('upload-reviewer@example.test', 'SecureTest123!@#') }
  let!(:upload) { create(:better_together_upload, creator: user.person, name: 'Held upload') }

  around do |example|
    original = BetterTogether.content_security

    config = ActiveSupport::OrderedOptions.new
    malware_scanning = ActiveSupport::OrderedOptions.new
    malware_scanning.enabled = true
    malware_scanning.engine = 'clamav'
    malware_scanning.host = '127.0.0.1'
    malware_scanning.port = 3310
    malware_scanning.timeout = 1
    malware_scanning.max_stream_bytes = 5.megabytes
    malware_scanning.fail_mode = 'hold_until_clean'
    malware_scanning.enabled_surfaces = ['uploads']
    config.malware_scanning = malware_scanning

    BetterTogether.content_security = config
    example.run
  ensure
    BetterTogether.content_security = original
  end

  before do
    upload.file.attach(io: StringIO.new('held upload'), filename: 'held.txt', content_type: 'text/plain')
    upload.save!
    sign_in user
  end

  it 'shows held-review status and disables insert actions for pending uploads' do
    get better_together.file_index_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Under review')
    expect(response.body).to include('reviewed before it can be inserted into rich text or shared')
    expect(response.body).to include('disabled')
  end
end
