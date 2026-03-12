# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe ConnectionRequest do
      it 'has a valid factory' do
        request = build(:better_together_joatu_connection_request)

        expect(request).to be_valid
        expect(request.target).to be_a(BetterTogether::Platform)
      end

      it 'is invalid when the target is not a platform' do
        request = build(:better_together_joatu_connection_request, target: create(:better_together_person))

        expect(request).not_to be_valid
        expect(request.errors[:target]).to include('must be a platform')
      end
    end
  end
end
