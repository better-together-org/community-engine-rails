# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::FeatureAccessGrantsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:platform_manager_user) do
    find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_steward)
  end
  let(:platform) do
    create(:better_together_platform,
           identifier: "feature-gate-platform-#{SecureRandom.hex(4)}",
           host_url: "https://feature-gate-platform-#{SecureRandom.hex(4)}.example.test")
  end

  before do
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
           BetterTogether::Role.find_by(identifier: 'platform_manager')

    platform.person_platform_memberships.find_or_create_by!(member: platform_manager_user.person, role:) do |membership|
      membership.status = 'active'
    end
  end

  def index_path
    platform_feature_access_grants_path(platform, locale:)
  end

  describe 'GET /host/platforms/:platform_id/feature_access_grants' do
    let!(:grant) do
      create(:better_together_feature_access_grant,
             platform:,
             feature_key: 'device_permissions')
    end

    it 'renders the index for platform managers' do
      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Feature Access Grants')
      # Faker-generated names occasionally contain an apostrophe (e.g. "O'Connell"),
      # which the view's HTML escaping renders as `&#39;` — compare against the
      # escaped form to match what's actually in the response body.
      expect(response.body).to include(CGI.escapeHTML(grant.person.select_option_title))
    end

    it 'redirects signed-in non-managers away from the route' do
      sign_in regular_user

      get index_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /host/platforms/:platform_id/feature_access_grants/new' do
    it 'renders the new form' do
      get new_platform_feature_access_grant_path(platform, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('feature_access_grant[feature_key]')
      expect(response.body).to include('feature_access_grant[person_id]')
    end
  end

  describe 'POST /host/platforms/:platform_id/feature_access_grants' do
    let(:person) { create(:better_together_person) }

    it 'creates a feature access grant for a specific person' do
      expect do
        post index_path,
             params: {
               feature_access_grant: {
                 person_id: person.id,
                 feature_key: 'device_permissions',
                 access_level: 'beta',
                 notes: 'QA tester rollout'
               }
             }
      end.to change(BetterTogether::FeatureAccessGrant, :count).by(1)

      expect(response).to have_http_status(:see_other)
      grant = BetterTogether::FeatureAccessGrant.order(created_at: :desc).first
      expect(grant.platform).to eq(platform)
      expect(grant.person).to eq(person)
      expect(grant.granted_by_person).to eq(platform_manager_user.person)
    end

    it 'rejects a duplicate active grant' do
      create(:better_together_feature_access_grant, platform:, person:)

      expect do
        post index_path,
             params: {
               feature_access_grant: {
                 person_id: person.id,
                 feature_key: 'device_permissions',
                 access_level: 'beta'
               }
             }
      end.not_to change(BetterTogether::FeatureAccessGrant, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'allows creating a replacement for an expired grant' do
      create(:better_together_feature_access_grant,
             platform:,
             person:,
             feature_key: 'device_permissions',
             expires_at: 1.day.ago)

      expect do
        post index_path,
             params: {
               feature_access_grant: {
                 person_id: person.id,
                 feature_key: 'device_permissions',
                 access_level: 'beta'
               }
             }
      end.to change(BetterTogether::FeatureAccessGrant, :count).by(1)

      expect(response).to have_http_status(:see_other)
    end
  end

  describe 'GET /host/platforms/:platform_id/feature_access_grants/:id/edit' do
    let!(:grant) { create(:better_together_feature_access_grant, platform:) }

    it 'renders the edit form' do
      get edit_platform_feature_access_grant_path(platform, grant, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(grant.person.select_option_title)
    end
  end

  describe 'PATCH /host/platforms/:platform_id/feature_access_grants/:id' do
    let!(:grant) { create(:better_together_feature_access_grant, platform:, notes: 'Original note') }

    it 'updates the grant' do
      patch platform_feature_access_grant_path(platform, grant, locale:),
            params: {
              feature_access_grant: {
                access_level: 'alpha',
                notes: 'Expanded for alpha validation'
              }
            }

      expect(response).to have_http_status(:see_other)
      expect(grant.reload.access_level).to eq('alpha')
      expect(grant.notes).to eq('Expanded for alpha validation')
    end

    it 'rejects invalid updates' do
      patch platform_feature_access_grant_path(platform, grant, locale:),
            params: {
              feature_access_grant: {
                access_level: 'invalid'
              }
            }

      expect(response).to have_http_status(:unprocessable_content)
      expect(grant.reload.access_level).to eq('beta')
    end
  end

  describe 'DELETE /host/platforms/:platform_id/feature_access_grants/:id' do
    let!(:grant) { create(:better_together_feature_access_grant, platform:) }

    it 'soft revokes the grant instead of deleting it' do
      expect do
        delete platform_feature_access_grant_path(platform, grant, locale:)
      end.not_to change(BetterTogether::FeatureAccessGrant, :count)

      expect(response).to have_http_status(:see_other)
      expect(grant.reload.revoked_at).to be_present
    end
  end

  describe 'host admin contract' do
    let!(:grant) { create(:better_together_feature_access_grant, platform:) }
    let(:other_platform) do
      create(:better_together_platform,
             identifier: "other-platform-#{SecureRandom.hex(4)}",
             host_url: "https://other-platform-#{SecureRandom.hex(4)}.example.test")
    end

    it 'does not allow a host platform manager to administer grants for another platform route' do
      foreign_grant = create(:better_together_feature_access_grant, platform: other_platform)

      get edit_platform_feature_access_grant_path(other_platform, foreign_grant, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'retired feature keys' do
    let!(:grant) { create(:better_together_feature_access_grant, platform:, feature_key: 'device_permissions') }

    it 'renders a fallback label instead of raising when a persisted grant references a retired feature key' do
      allow(BetterTogether::FeatureRegistry).to receive(:find).and_call_original
      allow(BetterTogether::FeatureRegistry).to receive(:find).with('device_permissions').and_return(nil)

      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Unknown feature (device_permissions)')
    end
  end
end
