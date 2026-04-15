# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Page management', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }
  let(:community) { create(:better_together_community, privacy: 'community') }
  let(:sidebar_nav) { create(:better_together_navigation_area) }
  let(:robot) { create(:better_together_robot, platform: BetterTogether::Platform.find_by(host: true)) }

  describe 'POST /api/v1/pages' do
    let(:url) { '/api/v1/pages' }
    let(:params) do
      {
        data: {
          type: 'pages',
          attributes: {
            title: 'Provisioned Package Hub',
            slug: 'provisioned-package-hub',
            privacy: 'private',
            layout: 'layouts/better_together/page_with_nav',
            show_title: true,
            published_at: nil,
            author_ids: [platform_manager_user.person.id],
            robot_author_ids: [robot.id],
            editor_ids: [platform_manager_user.person.id]
          },
          relationships: {
            community: {
              data: { type: 'communities', id: community.id }
            },
            creator: {
              data: { type: 'people', id: platform_manager_user.person.id }
            },
            sidebar_nav: {
              data: { type: 'navigation_areas', id: sidebar_nav.id }
            }
          }
        }
      }
    end

    it 'creates a page with slug, creator, sidebar nav, and governed contributors' do
      expect do
        post url, params: params.to_json, headers: platform_manager_headers.merge(jsonapi_headers)
      end.to change(BetterTogether::Page, :count).by(1)

      expect(response).to have_http_status(:created)

      created_page = BetterTogether::Page.order(created_at: :desc).first
      expect(created_page.slug).to eq('provisioned-package-hub')
      expect(created_page.creator).to eq(platform_manager_user.person)
      expect(created_page.community).to eq(community)
      expect(created_page.sidebar_nav).to eq(sidebar_nav)
      expect(created_page.authors).to include(platform_manager_user.person)
      expect(created_page.robot_authors).to include(robot)
      expect(created_page.editors).to include(platform_manager_user.person)
    end
  end

  describe 'PATCH /api/v1/pages/:id' do
    let(:page) do
      create(:better_together_page,
             creator: platform_manager_user.person,
             community: community,
             privacy: 'private',
             sidebar_nav: nil,
             slug: 'original-hub')
    end
    let(:url) { "/api/v1/pages/#{page.id}" }
    let(:params) do
      {
        data: {
          type: 'pages',
          id: page.id,
          attributes: {
            slug: 'updated-hub'
          },
          relationships: {
            sidebar_nav: {
              data: { type: 'navigation_areas', id: sidebar_nav.id }
            }
          }
        }
      }
    end

    it 'updates slug and sidebar nav' do
      patch url, params: params.to_json, headers: platform_manager_headers.merge(jsonapi_headers)

      expect(response).to have_http_status(:ok)
      page.reload
      expect(page.slug).to eq('updated-hub')
      expect(page.sidebar_nav).to eq(sidebar_nav)
    end
  end
end
