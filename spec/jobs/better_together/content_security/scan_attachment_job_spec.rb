# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::ScanAttachmentJob do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:upload) { create(:better_together_upload, creator: user.person) }

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

  it 'marks the item clean when the scanner reports a clean file' do
    item = upload.content_security_item
    result = BetterTogether::ContentSecurity::Scanner::Result.new(
      status: :clean,
      verdict: 'clean',
      scanner_name: 'clamav'
    )
    allow(BetterTogether::ContentSecurity::Scanner).to receive(:scan_blob).and_return(result)

    described_class.perform_now(item.id)

    expect(item.reload).to be_lifecycle_state_clean
    expect(item).to be_aggregate_verdict_clean
    expect(item.released_at).to be_present
    expect(item.scan_events.last).to be_status_completed
  end

  it 'quarantines infected uploads and opens a safety case' do
    item = upload.content_security_item
    result = BetterTogether::ContentSecurity::Scanner::Result.new(
      status: :infected,
      verdict: 'quarantined',
      scanner_name: 'clamav',
      signature_name: 'Eicar-Test-Signature'
    )
    allow(BetterTogether::ContentSecurity::Scanner).to receive(:scan_blob).and_return(result)

    described_class.perform_now(item.id)

    expect(item.reload).to be_lifecycle_state_quarantined
    expect(item.findings.last.finding_type).to eq('malware_signature')
    expect(item.safety_case).to be_present
    expect(item.safety_case.lane).to eq('technical_security')
    expect(item.safety_case.report.category).to eq('malware_detected')
  end

  it 're-raises ClamAvClient::ConnectionError so retry_on can handle transient failures' do
    item = upload.content_security_item
    result = BetterTogether::ContentSecurity::Scanner::Result.new(
      status: :error,
      verdict: 'review_required',
      scanner_name: 'clamav',
      error_class: 'clamav_connection_error',
      error_summary: 'Connection refused'
    )
    allow(BetterTogether::ContentSecurity::Scanner).to receive(:scan_blob).and_return(result)

    expect { described_class.perform_now(item.id) }.to raise_error(
      BetterTogether::ContentSecurity::ClamAvClient::ConnectionError
    )

    # Item stays pending_scan — not transitioned to review_required — so no false safety case.
    expect(item.reload).to be_lifecycle_state_pending_scan
  end

  it 'keeps item pending_scan and records the error when fail_mode is hold_until_clean' do
    item = upload.content_security_item
    result = BetterTogether::ContentSecurity::Scanner::Result.new(
      status: :error,
      verdict: 'review_required',
      scanner_name: 'clamav',
      error_class: 'clamav_scan_error',
      error_summary: 'Scanner internal error'
    )
    allow(BetterTogether::ContentSecurity::Scanner).to receive(:scan_blob).and_return(result)

    described_class.perform_now(item.id)

    expect(item.reload).to be_lifecycle_state_pending_scan
    expect(item.last_error_class).to eq('clamav_scan_error')
    expect(item.safety_case).to be_nil
  end

  it 'holds uploads for review and opens a safety case when fail_mode is not hold_until_clean' do
    BetterTogether.content_security.malware_scanning.fail_mode = 'review_required'

    item = upload.content_security_item
    result = BetterTogether::ContentSecurity::Scanner::Result.new(
      status: :error,
      verdict: 'review_required',
      scanner_name: 'clamav',
      error_class: 'clamav_scan_error',
      error_summary: 'Scanner internal error'
    )
    allow(BetterTogether::ContentSecurity::Scanner).to receive(:scan_blob).and_return(result)

    described_class.perform_now(item.id)

    expect(item.reload).to be_lifecycle_state_review_required
    expect(item.last_error_class).to eq('clamav_scan_error')
    expect(item.safety_case).to be_present
    expect(item.safety_case.report.category).to eq('scan_failure')
  end

  it 'skips already-assessed items without re-scanning' do
    item = upload.content_security_item
    item.update!(lifecycle_state: 'clean', aggregate_verdict: 'clean', released_at: Time.current)

    expect(BetterTogether::ContentSecurity::Scanner).not_to receive(:scan_blob)

    described_class.perform_now(item.id)

    expect(item.reload).to be_lifecycle_state_clean
  end
end
