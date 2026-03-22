# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonLinkedSeed do
  it 'is not eligible for global search surfaces' do
    expect(described_class.global_searchable?).to be(false)
    expect(BetterTogether::Searchable.included_in_models).not_to include(described_class)
  end

  it 'is visible only to the recipient while the grant is active' do
    linked_seed = create(:better_together_person_linked_seed)

    expect(linked_seed.viewable_by?(linked_seed.recipient_person)).to be(true)
    expect(linked_seed.viewable_by?(linked_seed.person_access_grant.grantor_person)).to be(false)
    expect(described_class.visible_to(linked_seed.recipient_person)).to include(linked_seed)
  end

  it 'encrypts the cached private payload at rest' do
    linked_seed = create(:better_together_person_linked_seed, payload: JSON.generate('secret' => 'private body'))

    expect(linked_seed.payload_data).to eq('secret' => 'private body')
    expect(linked_seed.read_attribute_before_type_cast('payload')).not_to include('private body')
  end

  it 'requires the recipient to match the access grant grantee' do
    linked_seed = build(:better_together_person_linked_seed, recipient_person: create(:better_together_person))

    expect(linked_seed).not_to be_valid
    expect(linked_seed.errors[:recipient_person]).to include('must match the access grant grantee person')
  end

  it 'becomes soft-hidden when the access grant is revoked' do
    linked_seed = create(:better_together_person_linked_seed)

    linked_seed.person_access_grant.revoke!

    expect(linked_seed.reload.soft_hidden?).to be(true)
    expect(linked_seed.viewable_by?(linked_seed.recipient_person)).to be(false)
    expect(described_class.visible_to(linked_seed.recipient_person)).not_to include(linked_seed)
  end
end
