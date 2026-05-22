# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::FeatureAccessGrantsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:platform) do
    create(:better_together_platform,
           identifier: "feature-gate-platform-#{SecureRandom.hex(4)}",
           host_url: "https://feature-gate-platform-#{SecureRandom.hex(4)}.example.test")
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
      expect(response.body).to include(grant.person.select_option_title)
    end

    it 'redirects signed-in non-managers away from the route' do
      sign_in regular_user

      get index_path

      expect(response).to have_http_status(:not_found)
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
      expect(grant.granted_by_person).to eq(BetterTogether::User.find_by(email: 'manager@example.test').person)
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
end
