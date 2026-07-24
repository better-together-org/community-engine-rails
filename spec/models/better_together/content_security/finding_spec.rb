# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::Finding do
  subject(:finding) do
    described_class.new(
      item: item,
      scan_event: scan_event,
      plane: 'technical',
      finding_type: 'malware_signature',
      rule_id: 'Eicar-Test-Signature',
      severity: 'high',
      confidence: 'high',
      verdict: 'quarantined',
      evidence_summary: 'Malware detected: Eicar-Test-Signature',
      detected_at: Time.current
    )
  end

  let(:upload) { create(:better_together_upload) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('test content'),
      filename: "test-#{SecureRandom.hex(4)}.txt",
      content_type: 'text/plain'
    )
  end
  let(:item) do
    BetterTogether::ContentSecurity::Item.create!(
      blob: blob,
      attachable: upload,
      attachment_name: 'file',
      source_surface: 'uploads',
      lifecycle_state: 'quarantined',
      aggregate_verdict: 'quarantined'
    )
  end
  let(:scan_event) do
    BetterTogether::ContentSecurity::ScanEvent.create!(
      item: item,
      status: 'completed',
      plane: 'technical',
      scanner_name: 'clamav',
      scanner_version: 'ClamAV 1.0.0',
      started_at: Time.current,
      verdict: 'quarantined'
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:item).class_name('BetterTogether::ContentSecurity::Item') }
    it { is_expected.to belong_to(:scan_event).class_name('BetterTogether::ContentSecurity::ScanEvent') }
    it { is_expected.to belong_to(:safety_case).class_name('BetterTogether::Safety::Case').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:plane) }
    it { is_expected.to validate_presence_of(:finding_type) }
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:confidence) }
    it { is_expected.to validate_presence_of(:verdict) }
    it { is_expected.to validate_presence_of(:detected_at) }

    it 'is valid with all required attributes' do
      expect(finding).to be_valid
    end

    it 'is invalid without plane' do
      finding.plane = nil
      expect(finding).not_to be_valid
    end

    it 'is invalid without detected_at' do
      finding.detected_at = nil
      expect(finding).not_to be_valid
    end
  end

  describe 'factory' do
    it 'produces a valid finding for malware signature' do
      f = create(:content_security_finding)
      expect(f).to be_persisted
      expect(f.finding_type).to eq('malware_signature')
    end

    it 'produces a valid scan_failure finding' do
      f = create(:content_security_finding, :scan_failure)
      expect(f).to be_persisted
      expect(f.finding_type).to eq('scan_failure')
      expect(f.verdict).to eq('review_required')
    end
  end
end
