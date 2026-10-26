# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the events and posts indexes when a community page embeds them as a lazy turbo-frame
# (?community_id=<slug>, Turbo-Frame request header) and when they are opened as plain pages.
RSpec.describe 'Framed indexes DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:creator) { create(:person) }
  let(:community) { create(:community, creator:) }
  let(:other_community) { create(:community, creator:) }
  let(:frame_headers) { { 'Turbo-Frame' => 'community-events' } }
  let(:hosted) { create(:event, platform:, creator:, name: 'Hosted by the community') }
  let(:unrelated) { create(:event, platform:, creator:, name: 'Hosted elsewhere') }

  before do
    hosted.event_hosts.destroy_all
    hosted.event_hosts.create!(host: community)
    unrelated.event_hosts.destroy_all
    unrelated.event_hosts.create!(host: other_community)
  end

  def index_path(resource, **params)
    "/#{I18n.default_locale}/#{resource}#{"?#{params.to_query}" if params.any?}"
  end

  describe 'events inside a frame' do
    before { get index_path(:events, community_id: community.slug), headers: frame_headers }

    it 'wraps the list in the requesting frame with an h2 heading and a card grid', :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="community-events" target="_top">')
      expect(response.body).to match(/<h2 class="mb-0">\s*Events|<h2 class="mb-0">Events/)
      expect(response.body).not_to include('<h1 class="mb-0">')
      expect(response.body).to include('class="frame-card-grid"')
    end

    it 'lists only the events the community hosts', :aggregate_failures do
      expect(response.body).to include('Hosted by the community')
      expect(response.body).not_to include('Hosted elsewhere')
    end

    it 'keeps the scope and the frame in the filter form', :aggregate_failures do
      expect(response.body).to include(%(data-turbo-frame="community-events"))
      hidden = Nokogiri::HTML(response.body).at_css('form.events-filter-sidebar input[name=community_id]')
      expect(hidden['value']).to eq(community.slug)
    end

    it 'keeps the filter toggle visible at every width', :aggregate_failures do
      toggle = Nokogiri::HTML(response.body).at_css('#events-filter-toggle')
      expect(toggle).to be_present
      expect(toggle['class']).not_to include('d-lg-none')
    end
  end

  describe 'events as a plain page' do
    it 'keeps the h1 and the sidebar layout, scoped to the community', :aggregate_failures do
      get index_path(:events, community_id: community.slug)

      expect(response.body).not_to include('<turbo-frame id="community-events"')
      expect(response.body).to include('<h1 class="mb-0">')
      expect(response.body).to include('col-lg-3')
      expect(response.body).not_to include('Hosted elsewhere')
    end

    it 'is a 404 for an unknown community' do
      get index_path(:events, community_id: 'no-such-community')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'posts inside a frame' do
    it 'wraps the list in the requesting frame with an h2 and a collapsible filter', :aggregate_failures do
      get index_path(:posts, community_id: community.slug), headers: { 'Turbo-Frame' => 'community-posts' }

      expect(response.body).to include('<turbo-frame id="community-posts" target="_top">')
      expect(response.body).to include('id="posts-filter-toggle"')
      expect(response.body).to include('id="posts-filter-sidebar"')
      expect(response.body).to include(%(data-turbo-frame="community-posts"))
    end
  end
end
