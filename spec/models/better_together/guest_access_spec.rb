# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GuestAccess do
  it 'inherits from PlatformInvitation (STI)' do
    expect(described_class.superclass).to eq(BetterTogether::PlatformInvitation)
  end

  describe '.model_name' do
    it 'returns a model name scoped to GuestAccess (not PlatformInvitation)' do
      expect(described_class.model_name.name).to eq('BetterTogether::GuestAccess')
    end
  end

  describe '#registers_user?' do
    it 'returns false' do
      expect(described_class.new.registers_user?).to be false
    end
  end
end
