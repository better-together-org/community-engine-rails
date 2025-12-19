# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonPlatformMemberships' do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:person) { create(:better_together_person) }
  let(:analytics_viewer_role) do
    BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer', resource_type: 'BetterTogether::Platform')
  end
  let(:manager_role) do
    BetterTogether::Role.find_by(identifier: 'platform_manager', resource_type: 'BetterTogether::Platform')
  end

  describe 'POST /platforms/:platform_id/person_platform_memberships' do
    context 'with valid parameters', :as_platform_manager do
      let(:valid_params) do
        {
          person_platform_membership: {
            member_id: person.id,
            role_id: analytics_viewer_role.id
          },
          locale: I18n.default_locale
        }
      end

      it 'creates a new platform membership with the specified role' do
        expect do
          post platform_person_platform_memberships_path(platform), params: valid_params
        end.to change(BetterTogether::PersonPlatformMembership, :count).by(1)

        membership = BetterTogether::PersonPlatformMembership.last
        expect(membership.member).to eq(person)
        expect(membership.role).to eq(analytics_viewer_role)
        expect(membership.joinable).to eq(platform)
      end

      it 'responds with turbo stream for successful creation' do
        post platform_person_platform_memberships_path(platform), params: valid_params,
                                                                  headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('turbo-stream')
      end

      it 'allows assigning the analytics_viewer role' do
        post platform_person_platform_memberships_path(platform), params: valid_params

        membership = BetterTogether::PersonPlatformMembership.last
        expect(membership.role.identifier).to eq('platform_analytics_viewer')
      end
    end

    context 'with invalid parameters', :as_platform_manager do
      # Create an existing membership to trigger uniqueness validation failure
      let!(:existing_membership) do
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: person,
               role: analytics_viewer_role)
      end

      let(:invalid_params) do
        {
          person_platform_membership: {
            member_id: person.id,
            role_id: analytics_viewer_role.id
          },
          locale: I18n.default_locale
        }
      end

      it 'does not create a membership' do
        expect do
          post platform_person_platform_memberships_path(platform), params: invalid_params
        end.not_to change(BetterTogether::PersonPlatformMembership, :count)
      end

      it 'responds with turbo stream showing errors' do
        post platform_person_platform_memberships_path(platform), params: invalid_params,
                                                                  headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('form_errors')
      end
    end

    context 'when assigning manager role', :as_platform_manager do
      let(:manager_params) do
        {
          person_platform_membership: {
            member_id: person.id,
            role_id: manager_role.id
          },
          locale: I18n.default_locale
        }
      end

      it 'creates a membership with manager role' do
        post platform_person_platform_memberships_path(platform), params: manager_params

        membership = BetterTogether::PersonPlatformMembership.last
        expect(membership.role.identifier).to eq('platform_manager')
      end
    end
  end

  describe 'DELETE /platforms/:platform_id/person_platform_memberships/:id' do
    context 'when user has permission', :as_platform_manager do
      let!(:membership) do
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: person,
               role: analytics_viewer_role)
      end

      it 'deletes the membership' do
        expect do
          delete platform_person_platform_membership_path(platform, membership),
                 params: { locale: I18n.default_locale }
        end.to change(BetterTogether::PersonPlatformMembership, :count).by(-1)
      end

      it 'responds with turbo stream' do
        delete platform_person_platform_membership_path(platform, membership),
               params: { locale: I18n.default_locale },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('turbo-stream')
      end
    end
  end

  describe 'authorization checks' do
    context 'when user lacks manage_platform permission', :as_user do
      let(:platform) { BetterTogether::Platform.find_by(host: true) }
      let(:person) { create(:better_together_person) }
      let(:analytics_viewer_role) do
        BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer', resource_type: 'BetterTogether::Platform')
      end

      let(:valid_params) do
        {
          person_platform_membership: {
            member_id: person.id,
            role_id: analytics_viewer_role.id
          },
          locale: I18n.default_locale
        }
      end

      it 'denies creating memberships with routing error' do
        expect do
          post platform_person_platform_memberships_path(platform), params: valid_params
        end.to raise_error(ActionController::RoutingError)
      end

      it 'denies deleting memberships with routing error' do
        membership = create(:better_together_person_platform_membership,
                            joinable: platform,
                            member: person,
                            role: analytics_viewer_role)

        expect do
          delete platform_person_platform_membership_path(platform, membership),
                 params: { locale: I18n.default_locale }
        end.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
