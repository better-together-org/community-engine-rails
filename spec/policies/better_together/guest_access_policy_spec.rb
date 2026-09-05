# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GuestAccessPolicy, type: :policy do
  it 'inherits from PlatformInvitationPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::PlatformInvitationPolicy)
  end

  describe 'Scope' do
    let(:user) { create(:better_together_user) }

    it 'resolves to all guest access records (STI on platform_invitations table)' do
      resolved = described_class::Scope.new(user, BetterTogether::GuestAccess).resolve
      expect(resolved.to_sql).to include('platform_invitations')
    end

    it 'Scope inherits from PlatformInvitationPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::PlatformInvitationPolicy::Scope)
    end
  end
end
