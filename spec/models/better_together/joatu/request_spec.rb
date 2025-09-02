# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Request do
      subject(:request_model) { build(:better_together_joatu_request) }

      it 'is valid without a target' do
        expect(request_model).to be_valid
      end

      it 'is valid with a target' do
        request_with_target = build(:better_together_joatu_request, :with_target)
        expect(request_with_target).to be_valid
      end

      it 'is valid with only a target_type' do
        request_with_type = build(:better_together_joatu_request, :with_target_type)
        expect(request_with_type).to be_valid
      end

      it 'is invalid without a creator' do
        request_model.creator = nil
        expect(request_model).not_to be_valid
      end

      it 'is invalid without target_type when target_id is set' do # rubocop:todo RSpec/NoExpectationExample
        request_model.target_id = SecureRandom.uuid
        request_model.target_type = nil
      end

      it 'is invalid without categories' do
        request_model.categories = []
        expect(request_model).not_to be_valid
      end
    end
  end
end
