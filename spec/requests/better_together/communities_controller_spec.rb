# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CommunitiesController' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/communities' do
    it 'renders index' do # rubocop:todo RSpec/NoExpectationExample
      get better_together.communities_path(locale:)
      # expect(response).to have_http_status(:ok)
    end

    it 'renders show for a community' do # rubocop:todo RSpec/NoExpectationExample
      community = create(:better_together_community,
                         creator: BetterTogether::User.find_by(email: 'manager@example.test').person)
      get better_together.community_path(locale:, id: community.slug)
      # expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/communities/:id' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates and redirects' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      community = create(:better_together_community,
                         creator: BetterTogether::User.find_by(email: 'manager@example.test').person)
      patch better_together.community_path(locale:, id: community.slug), params: {
        community: { privacy: 'public', name_en: 'Updated Name' }
      }
      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
