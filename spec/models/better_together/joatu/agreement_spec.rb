# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Agreement, type: :model do
      it 'accept! closes offer and request' do
        agreement = create(:better_together_joatu_agreement)
        agreement.accept!

        expect(agreement.status_accepted?).to be(true)
        expect(agreement.offer.status_closed?).to be(true)
        expect(agreement.request.status_closed?).to be(true)
      end
    end
  end
end
