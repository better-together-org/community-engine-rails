# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Authorships', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }
  let(:page) { create(:better_together_page, creator: platform_manager_user.person, privacy: 'private') }
  let(:robot) { create(:better_together_robot, platform: BetterTogether::Platform.find_by(host: true)) }

  describe 'POST /api/v1/authorships' do
    it 'creates a governed robot authorship for a page' do
      expect do
        post '/api/v1/authorships',
             params: {
               data: {
                 type: 'authorships',
                 attributes: {
                   author_id: robot.id,
                   author_type: 'BetterTogether::Robot',
                   authorable_id: page.id,
                   authorable_type: 'BetterTogether::Page',
                   role: 'author',
                   contribution_type: 'documentation',
                   position: 1
                 }
               }
             }.to_json,
             headers: platform_manager_headers.merge(jsonapi_headers)
      end.to change(BetterTogether::Authorship, :count).by(1)

      expect(response).to have_http_status(:created)
      authorship = BetterTogether::Authorship.order(created_at: :desc).first
      expect(authorship.author).to eq(robot)
      expect(authorship.authorable).to eq(page)
      expect(authorship.role).to eq('author')
      expect(authorship.contribution_type).to eq('documentation')
    end
  end
end
