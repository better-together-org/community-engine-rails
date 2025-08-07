# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ::BetterTogether::Geography::Country, type: :model do
    it 'exists' do
      expect(described_class).to be
    end
  end
end
