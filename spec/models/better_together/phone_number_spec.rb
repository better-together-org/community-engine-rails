# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PhoneNumber, type: :model do
    let(:contact_detail) { create(:contact_detail, contactable: create(:better_together_person)) }

    it 'is invalid without a number' do
      phone_number = build(:phone_number, contact_detail: contact_detail, number: nil)
      expect(phone_number).not_to be_valid
      expect(phone_number.errors[:number]).to include("can't be blank")
    end

    it 'is valid with a number' do
      phone_number = build(:phone_number, contact_detail: contact_detail, number: '123-456')
      expect(phone_number).to be_valid
    end
  end
end
