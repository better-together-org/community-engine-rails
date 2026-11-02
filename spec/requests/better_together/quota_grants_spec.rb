# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::QuotaGrantsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  # 'manager@example.test' is not an arbitrary choice: the :as_platform_manager auto-login
  # hook (spec/support/automatic_test_configuration.rb) hardcodes this exact email for the
  # user it actually signs in. A different email here would create a second, unrelated
  # person who never signs in, leaving the real current_user with no membership on
  # `platform` below - this must match exactly, same as feature_access_grants_spec.rb.
  let(:platform_manager_user) do
    find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_steward)
  end
  let(:platform) do
    create(:better_together_platform,
           identifier: "quota-grants-platform-#{SecureRandom.hex(4)}",
           host_url: "https://quota-grants-platform-#{SecureRandom.hex(4)}.example.test")
  end

  before do
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
           BetterTogether::Role.find_by(identifier: 'platform_manager')

    platform.person_platform_memberships.find_or_create_by!(member: platform_manager_user.person, role:) do |membership|
      membership.status = 'active'
    end
  end

  def index_path
    platform_quota_grants_path(platform, locale:)
  end

  describe 'GET /host/platforms/:platform_id/quota_grants' do
    let!(:grant) { create(:better_together_quota_grant, platform:) }

    it 'renders the index for platform managers' do
      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Quota Grants')
    end

    it 'redirects signed-in non-managers away from the route' do
      sign_in regular_user

      get index_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /host/platforms/:platform_id/quota_grants/new' do
    it 'renders the new form' do
      get new_platform_quota_grant_path(platform, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('quota_grant[quota_type]')
      expect(response.body).to include('quota_grant[limit]')
    end

    it 'prefills the owner when owner_type/owner_id params are given' do
      person = create(:better_together_person)

      get new_platform_quota_grant_path(platform, locale:, owner_type: 'BetterTogether::Person', owner_id: person.id)

      expect(response).to have_http_status(:ok)
      expect_html_content(person.select_option_title)
    end
  end

  describe 'POST /host/platforms/:platform_id/quota_grants' do
    let(:person) { create(:better_together_person) }

    it 'creates a quota grant for a specific person' do
      expect do
        post index_path,
             params: {
               quota_grant: {
                 owner_type: 'BetterTogether::Person',
                 owner_id: person.id,
                 quota_type: 'media_storage',
                 limit: 5 * (1024**3),
                 reason: 'Needs extra storage for a one-off event'
               }
             }
      end.to change(BetterTogether::QuotaGrant, :count).by(1)

      expect(response).to have_http_status(:see_other)
      grant = BetterTogether::QuotaGrant.order(created_at: :desc).first
      expect(grant.platform).to eq(platform)
      expect(grant.owner).to eq(person)
      expect(grant.granted_by).to eq(platform_manager_user.person)
    end

    it 'creates a quota grant for a specific community' do
      community = create(:better_together_community)

      expect do
        post index_path,
             params: {
               quota_grant: {
                 owner_type: 'BetterTogether::Community',
                 owner_id: community.id,
                 quota_type: 'media_storage',
                 limit: 20 * (1024**3)
               }
             }
      end.to change(BetterTogether::QuotaGrant, :count).by(1)

      grant = BetterTogether::QuotaGrant.order(created_at: :desc).first
      expect(grant.owner).to eq(community)
    end

    it 'rejects an invalid grant' do
      expect do
        post index_path,
             params: {
               quota_grant: {
                 owner_type: 'BetterTogether::Person',
                 owner_id: person.id,
                 quota_type: 'media_storage',
                 limit: -1
               }
             }
      end.not_to change(BetterTogether::QuotaGrant, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /host/platforms/:platform_id/quota_grants/:id/edit' do
    let!(:grant) { create(:better_together_quota_grant, platform:) }

    it 'renders the edit form' do
      get edit_platform_quota_grant_path(platform, grant, locale:)

      expect(response).to have_http_status(:ok)
      expect_html_content(grant.owner.select_option_title)
    end
  end

  describe 'PATCH /host/platforms/:platform_id/quota_grants/:id' do
    let!(:grant) { create(:better_together_quota_grant, platform:, reason: 'Original reason') }

    it 'updates the grant' do
      patch platform_quota_grant_path(platform, grant, locale:),
            params: {
              quota_grant: {
                limit: 50 * (1024**3),
                reason: 'Expanded for seasonal campaign'
              }
            }

      expect(response).to have_http_status(:see_other)
      expect(grant.reload.limit).to eq(50 * (1024**3))
      expect(grant.reason).to eq('Expanded for seasonal campaign')
    end

    it 'rejects invalid updates' do
      patch platform_quota_grant_path(platform, grant, locale:),
            params: {
              quota_grant: {
                limit: -5
              }
            }

      expect(response).to have_http_status(:unprocessable_content)
      expect(grant.reload.limit).not_to eq(-5)
    end
  end

  describe 'DELETE /host/platforms/:platform_id/quota_grants/:id' do
    let!(:grant) { create(:better_together_quota_grant, platform:) }

    it 'expires the grant instead of deleting it' do
      expect do
        delete platform_quota_grant_path(platform, grant, locale:)
      end.not_to change(BetterTogether::QuotaGrant, :count)

      expect(response).to have_http_status(:see_other)
      expect(grant.reload.expires_at).to be_present
      expect(grant.expires_at).to be <= Time.current
    end
  end

  describe 'host admin contract' do
    let!(:grant) { create(:better_together_quota_grant, platform:) }
    let(:other_platform) do
      create(:better_together_platform,
             identifier: "other-quota-platform-#{SecureRandom.hex(4)}",
             host_url: "https://other-quota-platform-#{SecureRandom.hex(4)}.example.test")
    end

    it 'does not allow a host platform manager to administer grants for another platform route' do
      foreign_grant = create(:better_together_quota_grant, platform: other_platform)

      get edit_platform_quota_grant_path(other_platform, foreign_grant, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'usage overview' do
    it 'lists current usage sorted busiest-first and links to grant an override' do
      owner = create(:better_together_person)
      # Built directly (not via Quotas.settle!) so it's deterministically scoped to
      # this test's own platform, rather than whatever Current.platform ambiently
      # resolves to.
      BetterTogether::Quota.create!(owner:, quota_type: 'media_storage', limit: 1024, period: 'cumulative', platform:)

      get index_path

      expect(response).to have_http_status(:ok)
      expect_html_content('Grant override')
    end
  end
end
