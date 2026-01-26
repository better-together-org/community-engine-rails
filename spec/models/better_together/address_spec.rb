# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe Address do
    describe 'factory' do
      it 'creates a valid address' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail)
        expect(address).to be_valid
        expect(address.label).to eq('work')
        expect(address.physical).to be true
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:contact_detail).class_name('BetterTogether::ContactDetail').optional }
      it { is_expected.to have_many(:buildings).class_name('BetterTogether::Infrastructure::Building') }
    end

    describe 'validations' do
      describe 'address type' do
        it 'requires at least one address type (physical or postal)' do
          person = create(:person)
          contact_detail = create(:contact_detail, contactable: person)
          address = build(:address, contact_detail: contact_detail, physical: false, postal: false)
          expect(address).not_to be_valid
          expect(address.errors[:base]).to be_present
        end

        it 'accepts physical address' do
          person = create(:person)
          contact_detail = create(:contact_detail, contactable: person)
          address = create(:address, contact_detail: contact_detail, physical: true, postal: false)
          expect(address).to be_valid
        end

        it 'accepts postal address' do
          person = create(:person)
          contact_detail = create(:contact_detail, contactable: person)
          address = create(:address, contact_detail: contact_detail, physical: false, postal: true)
          expect(address).to be_valid
        end

        it 'accepts both physical and postal' do
          person = create(:person)
          contact_detail = create(:contact_detail, contactable: person)
          address = create(:address, contact_detail: contact_detail, physical: true, postal: true)
          expect(address).to be_valid
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
        address = create(:address, contact_detail: contact_detail, label: 'main', primary_flag: true)
        expect(address.primary_flag).to be true
      end

      it 'scopes primary flag by contact_detail_id' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)

        address1 = create(:address,
                          contact_detail: contact_detail,
                          label: 'main',
                          line1: '123 Main St',
                          primary_flag: true)

        address2 = create(:address,
                          contact_detail: contact_detail,
                          label: 'work',
                          line1: '456 Work Ave',
                          primary_flag: false)

        expect(address1.primary_flag).to be true
        expect(address2.primary_flag).to be false
      end
    end

    describe 'Privacy concern' do
      it 'includes Privacy behavior' do
        expect(described_class.included_modules).to include(BetterTogether::Privacy)
      end

      it 'allows setting privacy level' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail, label: 'home', privacy: 'private')
        expect(address.privacy).to eq('private')
      end
    end

    describe 'Labelable concern' do
      it 'includes Labelable behavior' do
        expect(described_class.included_modules).to include(BetterTogether::Labelable)
      end

      it 'accepts valid labels' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        valid_labels = %w[main mailing physical home work billing shipping other]

        valid_labels.each do |label|
          address = build(:address, contact_detail: contact_detail, label: label)
          expect(address).to be_valid, "Expected #{label} to be valid"
        end
      end

      it 'defines expected label constants' do
        expect(described_class::LABELS).to include(:main, :mailing, :physical, :home, :work, :billing, :shipping, :other)
      end
    end

    describe 'geolocation' do
      it 'includes Geography::Geospatial::One behavior' do
        expect(described_class.included_modules).to include(BetterTogether::Geography::Geospatial::One)
      end

      it 'responds to geocoding_string method' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail)
        expect(address).to respond_to(:geocoding_string)
      end

      it 'builds geocoding string from address components' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail,
                                   line1: '62 Broadway',
                                   city_name: 'Corner Brook',
                                   state_province_name: 'Newfoundland and Labrador',
                                   postal_code: 'A2H 4C2',
                                   country_name: 'Canada')
        geocoding_string = address.geocoding_string
        expect(geocoding_string).to include('62 Broadway')
        expect(geocoding_string).to include('Corner Brook')
      end
    end

    describe 'string formatting' do
      it 'responds to to_formatted_s' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail)
        expect(address).to respond_to(:to_formatted_s)
      end

      it 'formats address as string' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail,
                                   line1: '62 Broadway',
                                   city_name: 'Corner Brook',
                                   state_province_name: 'NL',
                                   postal_code: 'A2H 4C2')
        formatted = address.to_s
        expect(formatted).to include('62 Broadway')
        expect(formatted).to include('Corner Brook')
      end

      it 'supports short format' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)
        address = create(:address, contact_detail: contact_detail,
                                   line1: '62 Broadway',
                                   line2: 'Suite 100',
                                   city_name: 'Corner Brook',
                                   state_province_name: 'NL')
        short = address.to_formatted_s(format: :short)
        expect(short).to include('62 Broadway')
        expect(short).not_to include('Suite 100') # line2 excluded in short format
      end
    end

    describe 'permitted_attributes' do
      it 'includes address-specific attributes' do
        attrs = described_class.permitted_attributes
        expect(attrs).to include(:physical, :postal, :line1, :line2, :city_name,
                                 :state_province_name, :postal_code, :country_name, :primary_flag)
      end
    end
  end
end
