# frozen_string_literal: true

require 'rails_helper'

# AttachmentSubjectSync (old Subject-based system) is superseded by AttachmentEnrollment
# for file attachments on Upload. These specs cover the new enrollment behavior triggered
# by ScannableAttachment#after_commit.
RSpec.describe BetterTogether::ContentSecurity::AttachmentEnrollment do
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

  it 'creates a pending_scan item for newly attached upload files' do
    upload.file.attach(io: StringIO.new('first file'), filename: 'first.txt', content_type: 'text/plain')
    upload.save!

    item = upload.reload.content_security_item

    expect(item).to be_present
    expect(item.blob).to eq(upload.file.blob)
    expect(item.lifecycle_state).to eq('pending_scan')
    expect(item.aggregate_verdict).to eq('pending_scan')
    expect(item.released_at).to be_nil
  end

  it 'resets the item to pending_scan when a new blob replaces a previously released file' do
    upload.file.attach(io: StringIO.new('old file'), filename: 'old.txt', content_type: 'text/plain')
    upload.save!
    upload.content_security_item.update!(
      lifecycle_state: 'clean',
      aggregate_verdict: 'clean',
      released_at: Time.current
    )

    upload.reload.file.attach(io: StringIO.new('new file'), filename: 'new.txt', content_type: 'text/plain')
    upload.save!

    item = upload.reload.content_security_item

    expect(item.blob).to eq(upload.file.blob)
    expect(item.lifecycle_state).to eq('pending_scan')
    expect(item.aggregate_verdict).to eq('pending_scan')
    expect(item.released_at).to be_nil
  end
end
