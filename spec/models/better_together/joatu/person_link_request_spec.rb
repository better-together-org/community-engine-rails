# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::PersonLinkRequest do
  it 'creates or activates a person link when an agreement is accepted' do
    source_platform = create(:better_together_platform)
    target_platform = create(:better_together_platform)
    platform_connection = create(:better_together_platform_connection, :active,
                                 source_platform:, target_platform:)
    source_person = create(:better_together_person)
    target_person = create(:better_together_person)

    source_platform.person_platform_memberships.create!(member: source_person, role: create(:better_together_role), status: 'active')
    target_platform.person_platform_memberships.create!(member: target_person, role: create(:better_together_role), status: 'active')

    offer = create(:better_together_joatu_offer, creator: source_person, target: source_person)
    request = create(:better_together_joatu_person_link_request, creator: target_person, target: target_person)
    agreement = create(:better_together_joatu_agreement, offer:, request:)

    expect { agreement.accept! }.to change(BetterTogether::PersonLink.active, :count).by(1)

    person_link = BetterTogether::PersonLink.find_by(platform_connection:, source_person:, target_person:)
    expect(person_link).to be_present
    expect(person_link).to be_active
  end
end
