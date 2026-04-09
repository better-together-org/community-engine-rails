# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailMessage do
  describe 'factory' do
    it 'builds a valid inbound email message' do
      expect(build(:inbound_email_message)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:inbound_email).class_name('ActionMailbox::InboundEmail') }
    it { is_expected.to belong_to(:platform).class_name('BetterTogether::Platform').optional }
    it { is_expected.to belong_to(:target).optional }
    it { is_expected.to belong_to(:routed_record).optional }
  end

  describe 'validations' do
    it 'requires routing and sender metadata' do
      message = build(:inbound_email_message, sender_email: nil, recipient_address: nil, message_id: nil, screening_state: nil)
      expect(message).not_to be_valid
      expect(message.errors[:sender_email]).to be_present
      expect(message.errors[:recipient_address]).to be_present
      expect(message.errors[:message_id]).to be_present
      expect(message.errors[:screening_state]).to be_present
    end
  end

  describe '#content_security_records' do
    it 'serializes and deserializes stored contract records' do
      message = build(:inbound_email_message)
      message.content_security_records = [{ 'record_type' => 'content_item', 'content_id' => 'csi_test_record' }]

      expect(message.content_security_records_json).to include('content_item')
      expect(message.content_security_records).to eq([{ 'record_type' => 'content_item', 'content_id' => 'csi_test_record' }])
    end
  end
end
