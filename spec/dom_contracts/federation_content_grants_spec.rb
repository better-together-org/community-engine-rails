# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the per-connection federation grants matrix: asserts the stable
# identifiers that documentation screenshots (spec/docs_screenshots/better_together/
# federation_hub_spec.rb#capture_post_federation_content_grants_field) and downstream
# tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Federation content grants DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:post_record) do
    create(:better_together_post, creator: platform_manager.person, privacy: 'public', published_at: 1.day.ago)
  end
  let!(:connection) do
    create(:better_together_platform_connection, :active, :sharing_enabled, share_posts: true)
  end

  describe 'GET /posts/:id/edit' do
    it 'exposes the grants section and a per-connection row for each eligible connection' do
      get better_together.edit_post_path(post_record, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("id=\"#{ActionView::RecordIdentifier.dom_id(post_record)}_federation_content_grants\"")
      expect(response.body).to include("id=\"federation-content-grant-#{connection.id}\"")
      expect(response.body).to include("post[federation_content_grants_by_connection][#{connection.id}]")
    end

    it 'omits the grants section entirely when no connection allows posts' do
      connection.update!(share_posts: false)

      get better_together.edit_post_path(post_record, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('_federation_content_grants"')
    end
  end
end
