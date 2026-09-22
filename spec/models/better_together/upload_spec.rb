# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Upload do
  subject(:upload) { build(:better_together_upload) }

  describe 'factory' do
    it 'is valid' do
      expect(upload).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to respond_to(:platform) }
    it { is_expected.to respond_to(:platform_id) }
    it { is_expected.to respond_to(:creator) }
  end

  it_behaves_like 'platform scoped identifier', factory: :better_together_upload
end
