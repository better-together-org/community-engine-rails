# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Request, type: :model do
      subject(:request_model) { build(:better_together_joatu_request) }

      it 'is valid with valid attributes' do
        expect(request_model).to be_valid
      end

      it 'is invalid without a creator' do
        request_model.creator = nil
        expect(request_model).not_to be_valid
      end
    end
  end
end
