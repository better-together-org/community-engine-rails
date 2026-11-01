# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CredentialCommunityBound do
  let!(:community_a) { create(:better_together_community) }
  let!(:community_b) { create(:better_together_community) }

  it 'leaves queries alone without a credential community' do
    expect(described_class.apply(BetterTogether::Community.all, nil).to_a).to include(community_a, community_b)
  end

  it 'limits communities to the credential community' do
    expect(described_class.apply(BetterTogether::Community.all, community_a).to_a).to contain_exactly(community_a)
  end

  it 'filters models with community_id' do
    page_a = create(:better_together_page, community: community_a, privacy: 'public')
    create(:better_together_page, community: community_b, privacy: 'public')

    expect(described_class.apply(BetterTogether::Page.all, community_a).to_a).to contain_exactly(page_a)
  end

  it 'returns nothing for models with no community linkage' do
    expect(described_class.apply(BetterTogether::Person.all, community_a)).to be_empty
  end

  describe 'through ApplicationPolicy::Scope#resolve' do
    it 'hides a private record the operator created in another community' do
      operator = create(:better_together_user, :confirmed, :platform_manager).person
      mine = create(:better_together_page, community: community_a, privacy: 'public')
      create(:better_together_page, community: community_b, privacy: 'private', creator: operator)
      Current.credential_community = community_a

      resolved = BetterTogether::PagePolicy::Scope.new(operator.user, BetterTogether::Page).resolve

      expect(resolved.to_a).to contain_exactly(mine)
    ensure
      Current.reset
    end
  end
end
