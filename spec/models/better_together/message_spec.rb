# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Message do
  describe 'Factory' do
    it 'has a valid factory' do
      message = build(:message)
      expect(message).to be_valid
    end

    it 'creates a message with content' do
      message = build(:message, content: 'Test message')
      message.save!(validate: false) # Skip validation to avoid factory callback issues initially
      expect(message.reload.content.to_plain_text).to include('Test message')
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:conversation).touch(true) }
    it { is_expected.to belong_to(:sender).class_name('BetterTogether::Person') }
  end

  describe 'Validations' do
    it 'requires content' do
      message = build(:message, content: nil)
      expect(message).not_to be_valid
      expect(message.errors[:content]).to include("can't be blank")
    end

    it 'accepts valid content' do
      message = build(:message, content: 'Valid message')
      expect(message).to be_valid
    end
  end

  describe 'Action Text Integration' do
    it 'has rich text content' do
      message = build(:message, content: 'Rich text')
      message.save!(validate: false)
      expect(message.content).to be_a(ActionText::RichText)
    end

    it 'converts content to plain text' do
      message = build(:message, content: '<p>Rich <strong>text</strong></p>')
      message.save!(validate: false)
      plain_text = message.reload.content.to_plain_text.strip
      expect(plain_text).to eq('Rich text')
    end
  end

  describe 'Class Methods' do
    describe '.permitted_attributes' do
      it 'returns an array with expected attributes' do
        expect(described_class.permitted_attributes).to match_array(%i[id content _destroy])
      end
    end
  end
end
