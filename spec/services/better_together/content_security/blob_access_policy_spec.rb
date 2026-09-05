# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::BlobAccessPolicy, type: :service do
  let(:upload) { create(:better_together_upload) }

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
    upload.file.attach(io: StringIO.new('proxy file'), filename: 'proxy.txt', content_type: 'text/plain')
    BetterTogether::ContentSecurity::AttachmentEnrollment.sync_attachment!(
      record: upload,
      attachment_name: :file,
      surface: :uploads
    )
  end

  it 'blocks public proxy access while the item is pending scan' do
    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(false)
  end

  it 'allows public proxy access after the item is marked clean' do
    upload.content_security_item.update!(
      lifecycle_state: 'clean',
      aggregate_verdict: 'clean',
      released_at: Time.current
    )

    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(true)
  end

  it 'blocks public proxy access for quarantined items' do
    upload.content_security_item.update!(
      lifecycle_state: 'quarantined',
      aggregate_verdict: 'quarantined'
    )

    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(false)
  end

  it 'allows proxy access unconditionally when scanning is disabled' do
    BetterTogether.content_security.malware_scanning.enabled = false

    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(true)
  end
end
