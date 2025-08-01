# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe JwtDenylist, type: :model do
    it 'uses the expected table name' do
      expect(described_class.table_name).to eq('better_together_jwt_denylists')
    end
  end
end
