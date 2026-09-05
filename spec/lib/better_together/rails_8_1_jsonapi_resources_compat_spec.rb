# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Rails81JSONAPIResourcesCompat do
    it 'keeps the legacy constant alias available' do
      expect(BetterTogether::Rails81JsonapiResourcesCompat).to be(described_class)
    end
  end
end
