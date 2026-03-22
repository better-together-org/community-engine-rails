# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EmailAddress do
  describe 'factory' do
    it 'creates a valid email address' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email_address = create(:email_address, contact_detail: contact_detail)
      expect(email_address).to be_valid
    end

    it 'generates unique email addresses' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email1 = create(:email_address, contact_detail: contact_detail, primary_flag: true)
      email2 = create(:email_address, contact_detail: contact_detail, primary_flag: false)
      expect(email1.email).not_to eq(email2.email)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:contact_detail).class_name('BetterTogether::ContactDetail').touch(true) }
  end

  describe 'validations' do
    describe 'email presence' do
      it 'requires email to be present' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        email_address = build(:email_address, contact_detail: contact_detail, email: nil)
        expect(email_address).not_to be_valid
        expect(email_address.errors[:email]).to include("can't be blank")
      end
    end

    describe 'email format' do
      it 'accepts valid email formats' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        valid_emails = [
          'user@example.com',
          'first.last@example.com',
          'user+tag@example.co.uk',
          'test_email@subdomain.example.com'
        ]

        valid_emails.each do |email|
          email_address = build(:email_address, contact_detail: contact_detail, email: email)
          expect(email_address).to be_valid, "Expected #{email} to be valid"
        end
      end

      it 'rejects invalid email formats' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        invalid_emails = [
          'invalid',
          '@example.com',
          'user@',
          'user @example.com'
        ]

        invalid_emails.each do |email|
          email_address = build(:email_address, contact_detail: contact_detail, email: email)
          expect(email_address).not_to be_valid, "Expected #{email} to be invalid"
          expect(email_address.errors[:email]).to be_present
        end
      end
    end
  end

  describe 'PrimaryFlag concern' do
    it 'includes PrimaryFlag behavior' do
      expect(described_class.included_modules).to include(BetterTogether::PrimaryFlag)
    end

    it 'allows setting primary_flag' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email_address = create(:email_address, contact_detail: contact_detail, primary_flag: true)
      expect(email_address.primary_flag).to be true
    end

    it 'scopes primary flag by contact_detail_id' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email1 = create(:email_address, contact_detail: contact_detail, primary_flag: true)
      email2 = create(:email_address, contact_detail: contact_detail, primary_flag: false)

      expect(email1.primary_flag).to be true
      expect(email2.primary_flag).to be false
    end
  end

  describe 'Privacy concern' do
    it 'includes Privacy behavior' do
      expect(described_class.included_modules).to include(BetterTogether::Privacy)
    end

    it 'allows setting privacy level' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email_address = create(:email_address, contact_detail: contact_detail, privacy: 'private')
      expect(email_address.privacy).to eq('private')
    end
  end

  describe 'Labelable concern' do
    it 'includes Labelable behavior' do
      expect(described_class.included_modules).to include(BetterTogether::Labelable)
    end

    it 'accepts valid labels' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)

      BetterTogether::EmailAddress::LABELS.each do |label|
        email_address = build(:email_address, contact_detail: contact_detail, label: label.to_s)
        expect(email_address).to be_valid
      end
    end

    it 'defines expected label constants' do
      expect(BetterTogether::EmailAddress::LABELS).to include(:personal, :work, :school, :other)
    end
  end

  describe 'touch association' do
    it 'touches contact_detail on update' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      email_address = create(:email_address, contact_detail: contact_detail)

      original_updated_at = contact_detail.updated_at
      sleep 0.01
      email_address.update!(email: 'newemail@example.com')

      expect(contact_detail.reload.updated_at).to be > original_updated_at
    end
  end
end
