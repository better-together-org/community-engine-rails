# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::ScanEvent do
  let(:item) { create(:content_security_item) }

  describe 'validations' do
    subject(:scan_event) do
      described_class.new(
        item: item,
        status: 'completed',
        plane: 'technical',
        scanner_name: 'clamav',
        started_at: Time.current
      )
    end

    it 'is valid with required attributes' do
      expect(scan_event).to be_valid
    end

    it 'requires status' do
      scan_event.status = nil
      expect(scan_event).not_to be_valid
    end

    it 'requires plane' do
      scan_event.plane = nil
      expect(scan_event).not_to be_valid
    end

    it 'requires scanner_name' do
      scan_event.scanner_name = nil
      expect(scan_event).not_to be_valid
    end

    it 'requires started_at' do
      scan_event.started_at = nil
      expect(scan_event).not_to be_valid
    end
  end

  describe 'enum :status' do
    it 'recognizes started' do
      event = create(:content_security_scan_event, status: 'started')
      expect(event.status_started?).to be true
    end

    it 'recognizes completed' do
      event = create(:content_security_scan_event, status: 'completed')
      expect(event.status_completed?).to be true
    end

    it 'recognizes failed' do
      event = create(:content_security_scan_event, status: 'failed')
      expect(event.status_failed?).to be true
    end

    it 'recognizes skipped' do
      event = create(:content_security_scan_event, status: 'skipped')
      expect(event.status_skipped?).to be true
    end
  end

  describe 'associations' do
    it 'belongs to item' do
      event = create(:content_security_scan_event)
      expect(event.item).to be_a(BetterTogether::ContentSecurity::Item)
    end

    it 'has many findings' do
      event = create(:content_security_scan_event)
      expect(event).to respond_to(:findings)
    end
  end
end
