# frozen_string_literal: true

require 'rails_helper'

# Contact details have no routes of their own; they change only through their contactable's update form.
RSpec.describe 'Contact detail ownership', :as_user do
  let(:locale) { I18n.default_locale }
  let(:owner) { create(:better_together_user, :confirmed) }
  let(:detail) { owner.person.contact_detail.reload }
  let(:email) { create(:email_address, contact_detail: detail, email: 'kept@example.test', primary_flag: false) }

  it 'does not let another signed-in user change or remove a person contact detail', :aggregate_failures do
    email
    patch better_together.person_path(locale:, id: owner.person.slug), params: {
      person: { contact_detail_attributes: { id: detail.id,
                                             email_addresses_attributes: { '0' => { id: email.id, _destroy: '1' } } } }
    }

    expect(response).not_to have_http_status(:ok)
    expect(BetterTogether::EmailAddress.exists?(email.id)).to be true
    expect(email.reload.email).to eq('kept@example.test')
  end

  it 'does not let a non-organizer change a community contact detail', :aggregate_failures do
    community = create(:better_together_community, creator: owner.person, privacy: 'public')
    kept = create(:email_address, contact_detail: community.contact_detail.reload, email: 'community@example.test',
                                  primary_flag: false)

    patch better_together.community_path(locale:, id: community.slug), params: {
      community: { contact_detail_attributes: { id: community.contact_detail.id,
                                                email_addresses_attributes: { '0' => { id: kept.id, _destroy: '1' } } } }
    }

    expect(BetterTogether::EmailAddress.exists?(kept.id)).to be true
  end
end
