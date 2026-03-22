# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ContactDetail do
    describe 'factory' do
      it 'creates a valid contact detail' do
        contact_detail = build(:contact_detail)
        expect(contact_detail).to be_valid
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:contactable) }
      it { is_expected.to have_many(:phone_numbers).dependent(:destroy) }
      it { is_expected.to have_many(:email_addresses).dependent(:destroy) }
      it { is_expected.to have_many(:addresses).dependent(:destroy) }
      it { is_expected.to have_many(:social_media_accounts).dependent(:destroy) }
      it { is_expected.to have_many(:website_links).dependent(:destroy) }
    end

    describe 'polymorphic contactable' do
      it 'can belong to a person' do
        person = create(:person)
        contact_detail = create(:contact_detail, contactable: person)

        expect(contact_detail.contactable).to eq(person)
        expect(contact_detail.contactable_type).to eq('BetterTogether::Person')
      end

      it 'can belong to a community' do
        community = create(:community)
        contact_detail = create(:contact_detail, contactable: community)

        expect(contact_detail.contactable).to eq(community)
        expect(contact_detail.contactable_type).to eq('BetterTogether::Community')
      end
    end

    describe '#has_contact_details?' do
      it 'returns false when no details present' do
        contact_detail = create(:contact_detail)
        expect(contact_detail.has_contact_details?).to be false
      end

      it 'checks for presence of any contact detail type' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to respond_to(:has_contact_details?)
      end
    end

    describe 'nested attributes support' do
      it 'accepts nested attributes for phone numbers' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to accept_nested_attributes_for(:phone_numbers).allow_destroy(true)
      end

      it 'accepts nested attributes for email addresses' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to accept_nested_attributes_for(:email_addresses).allow_destroy(true)
      end

      it 'accepts nested attributes for addresses' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to accept_nested_attributes_for(:addresses).allow_destroy(true)
      end

      it 'accepts nested attributes for social media accounts' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to accept_nested_attributes_for(:social_media_accounts).allow_destroy(true)
      end

      it 'accepts nested attributes for website links' do
        contact_detail = create(:contact_detail)
        expect(contact_detail).to accept_nested_attributes_for(:website_links).allow_destroy(true)
      end
    end

    describe 'safe touch behavior' do
      it 'touches contactable after create' do
        person = create(:person)
        original_time = person.updated_at

        sleep 0.01 # Small delay to ensure time difference
        create(:contact_detail, contactable: person)

        expect(person.reload.updated_at).to be > original_time
      end
    end
  end
end
