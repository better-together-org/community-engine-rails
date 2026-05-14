# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether upload download security' do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:upload) { create(:better_together_upload, creator: user.person, privacy: 'private') }

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
    host! 'www.example.com'
    sign_in user
    upload.file.attach(
      io: StringIO.new('safe-content'),
      filename: 'sample.txt',
      content_type: 'text/plain'
    )
    BetterTogether::ContentSecurity::AttachmentEnrollment.sync_attachment!(
      record: upload,
      attachment_name: :file,
      surface: :uploads
    )
  end

  it 'blocks download while the upload is pending scan' do
    get "/en/bt/f/#{upload.id}/download"

    expect(response).to redirect_to('http://www.example.com/')
  end

  it 'allows download after the upload is released' do
    upload.content_security_item.update!(
      lifecycle_state: 'clean',
      aggregate_verdict: 'clean',
      released_at: Time.current
    )

    get "/en/bt/f/#{upload.id}/download"

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq('safe-content')
  end
end
