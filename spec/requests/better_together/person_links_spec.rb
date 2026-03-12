# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonLinks', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:person_link) { create(:better_together_person_link) }
  let(:source_person) { person_link.source_person }
  let(:target_person) { person_link.target_person }
  let(:source_user) { create(:better_together_user, :confirmed, person: source_person, password:) }
  let(:target_user) { create(:better_together_user, :confirmed, person: target_person, password:) }
  let(:other_user) { create(:better_together_user, :confirmed, password:) }
  let!(:linked_grant) { create(:better_together_person_access_grant, person_link:) }

  describe 'GET /person-links' do
    it 'allows the source person to list their links' do
      login(source_user.email, password)

      get better_together.person_links_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person_link.status.humanize)
    end

    it 'does not show unrelated links to other users' do
      login(other_user.email, password)

      get better_together.person_links_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(person_link.id)
    end
  end

  describe 'GET /person-links/:id' do
    it 'allows the target person to view link metadata' do
      login(target_user.email, password)

      get better_together.person_link_path(person_link, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Person Link')
      expect(response.body).to include(linked_grant.status.humanize)
    end

    it 'hides the link from unrelated users' do
      login(other_user.email, password)

      get better_together.person_link_path(person_link, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /person-links/:id/revoke' do
    it 'allows the source person to revoke the link and cascades grant revocation' do
      login(source_user.email, password)

      post better_together.revoke_person_link_path(person_link, locale:)

      expect(response).to have_http_status(:see_other)
      expect(person_link.reload).to be_revoked
      expect(linked_grant.reload).to be_revoked
    end

    it 'rejects revoke attempts from non-source users' do
      login(other_user.email, password)

      post better_together.revoke_person_link_path(person_link, locale:)

      expect(response).to have_http_status(:not_found)
      expect(person_link.reload).to be_active
    end
  end
end
