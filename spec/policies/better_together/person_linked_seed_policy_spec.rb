# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonLinkedSeedPolicy do
  subject(:policy) { described_class.new(user, linked_seed) }

  let(:linked_seed) { create(:better_together_person_linked_seed) }
  let(:recipient) { linked_seed.recipient_person }
  let(:grantor) { linked_seed.person_access_grant.grantor_person }
  let!(:recipient_user) { create(:better_together_user, :confirmed, person: recipient) }
  let!(:grantor_user) { create(:better_together_user, :confirmed, person: grantor) }
  let(:user) { recipient_user }

  describe '#show?' do
    it 'allows the recipient to view the linked seed' do
      expect(policy.show?).to be(true)
    end

    it 'denies the grantor from viewing the linked seed payload' do
      expect(described_class.new(grantor_user, linked_seed).show?).to be(false)
    end

    it 'denies the recipient when the grant is revoked' do
      linked_seed.person_access_grant.revoke!

      expect(policy.show?).to be(false)
    end
  end

  describe described_class::Scope do
    it 'returns only linked seeds visible to the recipient' do
      other_linked_seed = create(:better_together_person_linked_seed)

      resolved = BetterTogether::PersonLinkedSeedPolicy::Scope.new(user, BetterTogether::PersonLinkedSeed.all).resolve

      expect(resolved).to include(linked_seed)
      expect(resolved).not_to include(other_linked_seed)
    end

    it 'excludes linked seeds whose grants are no longer active' do
      linked_seed.person_access_grant.revoke!

      resolved = BetterTogether::PersonLinkedSeedPolicy::Scope.new(user, BetterTogether::PersonLinkedSeed.all).resolve

      expect(resolved).not_to include(linked_seed)
    end
  end
end
