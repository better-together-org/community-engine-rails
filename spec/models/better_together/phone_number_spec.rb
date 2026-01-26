# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PhoneNumber do
  describe 'factory' do
    it 'creates a valid phone number' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      phone_number = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-123-4567',
        label: 'mobile',
        primary_flag: true
      )
      expect(phone_number).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:contact_detail).class_name('BetterTogether::ContactDetail').touch(true) }
  end

  describe 'validations' do
    describe 'number presence' do
      it 'requires number to be present' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        phone_number = described_class.new(
          contact_detail: contact_detail,
          number: nil,
          primary_flag: true
        )
        expect(phone_number).not_to be_valid
        expect(phone_number.errors[:number]).to include("can't be blank")
      end
    end

    describe 'number format' do
      it 'accepts various phone number formats' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        valid_numbers = [
          '+1-555-123-4567',
          '555-123-4567',
          '(555) 123-4567',
          '555.123.4567',
          '5551234567',
          '+44 20 7946 0958'
        ]

        valid_numbers.each_with_index do |number, index|
          phone = described_class.create!(
            contact_detail: contact_detail,
            number: number,
            label: 'mobile',
            primary_flag: (index == 0) # Only first one is primary
          )
          expect(phone).to be_valid
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
      phone_number = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-123-4567',
        label: 'mobile',
        primary_flag: true
      )
      expect(phone_number.primary_flag).to be true
    end

    it 'scopes primary flag by contact_detail_id' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      phone1 = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-111-1111',
        label: 'mobile',
        primary_flag: true
      )
      phone2 = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-222-2222',
        label: 'home',
        primary_flag: false
      )

      expect(phone1.primary_flag).to be true
      expect(phone2.primary_flag).to be false
    end
  end

  describe 'Privacy concern' do
    it 'includes Privacy behavior' do
      expect(described_class.included_modules).to include(BetterTogether::Privacy)
    end

    it 'allows setting privacy level' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      phone_number = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-123-4567',
        label: 'mobile',
        primary_flag: true,
        privacy: 'private'
      )
      expect(phone_number.privacy).to eq('private')
    end
  end

  describe 'Labelable concern' do
    it 'includes Labelable behavior' do
      expect(described_class.included_modules).to include(BetterTogether::Labelable)
    end

    it 'accepts valid labels' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)

      BetterTogether::PhoneNumber::LABELS.each_with_index do |label, index|
        phone = described_class.create!(
          contact_detail: contact_detail,
          number: "+1-555-#{100 + index}-0000",
          label: label.to_s,
          primary_flag: (index == 0)
        )
        expect(phone).to be_valid
      end
    end

    it 'defines expected label constants' do
      expect(BetterTogether::PhoneNumber::LABELS).to include(:mobile, :home, :work, :fax, :other)
    end
  end

  describe 'touch association' do
    it 'touches contact_detail on update' do
      person = create(:person)
      contact_detail = create(:contact_detail, contactable: person)
      phone_number = described_class.create!(
        contact_detail: contact_detail,
        number: '+1-555-123-4567',
        label: 'mobile',
        primary_flag: true
      )

      original_updated_at = contact_detail.updated_at
      sleep 0.01
      phone_number.update!(number: '+1-555-999-9999')

      expect(contact_detail.reload.updated_at).to be > original_updated_at
    end
  end
end
