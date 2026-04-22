# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonAccessGrants', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:grant) { create(:better_together_person_access_grant, allow_private_posts: true) }
  let(:grantor_person) { grant.grantor_person }
  let(:grantee_person) { grant.grantee_person }
  let(:grantor_user) { create(:better_together_user, :confirmed, person: grantor_person, password:) }
  let(:grantee_user) { create(:better_together_user, :confirmed, person: grantee_person, password:) }
  let(:other_user) { create(:better_together_user, :confirmed, password:) }
  let!(:linked_seed) do
    create(:better_together_person_linked_seed, person_access_grant: grant, recipient_person: grantee_person)
  end

  describe 'GET /access-grants' do
    it 'returns 404 for unauthenticated users' do
      get better_together.person_access_grants_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'allows the grantor to list their grants' do
      login(grantor_user.email, password)

      get better_together.person_access_grants_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(grant.status.humanize)
    end

    it 'does not show unrelated grants to other users' do
      login(other_user.email, password)

      get better_together.person_access_grants_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(grant.id)
    end
  end

  describe 'GET /access-grants/:id' do
    it 'allows the grantee to view grant metadata' do
      login(grantee_user.email, password)

      get better_together.person_access_grant_path(grant, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.person_access_grants.show.title'))
      expect(response.body).to include(
        I18n.t('better_together.person_access_grants.show.scope_labels.private_posts')
      )
      expect(response.body).to include(I18n.t('better_together.person_access_grants.show.allowed'))
    end

    it 'hides the grant from unrelated users' do
      login(other_user.email, password)

      get better_together.person_access_grant_path(grant, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /access-grants/:id' do
    it 'allows the grantor to narrow scopes' do
      login(grantor_user.email, password)

      patch better_together.person_access_grant_path(grant, locale:),
            params: { person_access_grant: { allow_private_posts: false, allow_private_pages: true } }

      expect(response).to have_http_status(:see_other)
      expect(grant.reload.allow_private_posts?).to be(false)
      expect(grant.allow_private_pages?).to be(true)
    end

    it 'rejects updates from non-grantors' do
      login(other_user.email, password)

      patch better_together.person_access_grant_path(grant, locale:),
            params: { person_access_grant: { allow_private_posts: false } }

      expect(response).to have_http_status(:not_found)
      expect(grant.reload.allow_private_posts?).to be(true)
    end
  end

  describe 'POST /access-grants/:id/revoke' do
    it 'raises a routing error when unauthenticated because the route is constrained' do
      expect do
        post better_together.revoke_person_access_grant_path(grant, locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'allows the grantor to revoke the grant and soft-hide cached linked seeds' do
      login(grantor_user.email, password)

      post better_together.revoke_person_access_grant_path(grant, locale:)

      expect(response).to have_http_status(:see_other)
      expect(grant.reload).to be_revoked
      expect(linked_seed.reload.soft_hidden?).to be(true)
    end

    it 'rejects revoke attempts from non-grantors' do
      login(other_user.email, password)

      post better_together.revoke_person_access_grant_path(grant, locale:)

      expect(response).to have_http_status(:not_found)
      expect(grant.reload).to be_active
    end
  end
end
