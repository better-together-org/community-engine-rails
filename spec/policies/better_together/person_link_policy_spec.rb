# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonLinkPolicy do
  subject(:policy) { described_class.new(user, person_link) }

  let(:person_link) { create(:better_together_person_link) }
  let(:source_person) { person_link.source_person }
  let(:target_person) { person_link.target_person }
  let!(:source_user) { create(:better_together_user, :confirmed, person: source_person) }
  let!(:target_user) { create(:better_together_user, :confirmed, person: target_person) }
  let(:user) { source_user }

  it 'allows the source person to show and revoke the link' do
    expect(policy.show?).to be(true)
    expect(policy.revoke?).to be(true)
  end

  it 'allows the target person to show but not revoke the link' do
    target_policy = described_class.new(target_user, person_link)

    expect(target_policy.show?).to be(true)
    expect(target_policy.revoke?).to be(false)
  end

  it 'scopes links to participants only' do
    other_link = create(:better_together_person_link)

    resolved = BetterTogether::PersonLinkPolicy::Scope.new(user, BetterTogether::PersonLink.all).resolve

    expect(resolved).to include(person_link)
    expect(resolved).not_to include(other_link)
  end
end
