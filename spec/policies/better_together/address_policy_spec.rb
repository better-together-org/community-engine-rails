# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AddressPolicy, type: :policy do
  it 'inherits from ContactDetailPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::ContactDetailPolicy)
  end

  describe '#create?' do
    it 'lets a signed-in user create a standalone address (picked location)' do
      user = create(:better_together_user)
      expect(described_class.new(user, BetterTogether::Address).create?).to be true
    end

    it 'denies anonymous' do
      expect(described_class.new(nil, BetterTogether::Address).create?).to be false
    end
  end

  describe '#destroy?' do
    it 'denies anonymous and class-level checks' do
      expect(described_class.new(nil, BetterTogether::Address).destroy?).to be false
    end
  end

  describe 'Scope' do
    let(:steward_user) { create(:better_together_user, :platform_steward) }
    let(:normal_user) { create(:better_together_user) }

    it 'inherits from ContactDetailPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::ContactDetailPolicy::Scope)
    end

    it 'resolves without error for a platform manager' do
      expect do
        described_class::Scope.new(steward_user, BetterTogether::Address).resolve
      end.not_to raise_error
    end

    context 'with a public address on a private platform' do
      let(:private_platform) { create(:better_together_platform, privacy: 'private') }
      let!(:address) do
        Current.platform = private_platform
        create(:better_together_address, platform: private_platform, privacy: 'public')
      end

      after { Current.reset }

      it 'hides it from anonymous callers', :aggregate_failures do
        expect(address.effective_privacy).to eq('community')
        expect(described_class::Scope.new(nil, BetterTogether::Address).resolve).not_to include(address)
      end

      it 'keeps it visible to a signed in user, as the platform gate does', :aggregate_failures do
        user = create(:better_together_user)
        expect(described_class::Scope.new(user, BetterTogether::Address).resolve).to include(address)
      end
    end

    context 'with a public address on a public platform' do
      let(:open_platform) { create(:better_together_platform, privacy: 'public') }

      it 'shows it to anonymous callers' do
        Current.platform = open_platform
        address = create(:better_together_address, platform: open_platform, privacy: 'public')
        expect(described_class::Scope.new(nil, BetterTogether::Address).resolve).to include(address)
      ensure
        Current.reset
      end
    end

    it 'resolves without error for a normal user' do
      expect do
        described_class::Scope.new(normal_user, BetterTogether::Address).resolve
      end.not_to raise_error
    end
  end
end
