# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the community page hooks a host app overrides: the header media, the location line and the
# empty About extra. The default render is unchanged; an override replaces only its own partial.
RSpec.describe 'Community show hooks DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:community) { create(:community, creator: create(:person), privacy: 'public') }
  let(:page_html) { Nokogiri::HTML(response.body) }

  def show_path
    "/#{I18n.default_locale}/c/#{community.slug}"
  end

  describe 'default render' do
    before { get show_path }

    it 'keeps the header cover and profile image under stable ids', :aggregate_failures do
      header = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(community, :profile_header)}")

      expect(header).to be_present
      expect(header.at_css("#cover_community_#{community.id}.cover-image-container")).to be_present
      expect(header.at_css("#profile_image_community_#{community.id}.profile-image-wrapper")).to be_present
    end

    it 'shows no location line and no extra content for an unlocated community', :aggregate_failures do
      expect(page_html.at_css('#community-location')).to be_nil
      expect(page_html.at_css('#community-description')).to be_present
    end

    it 'shows the location line when the community has a named location', :aggregate_failures do
      community.create_location!(location: create(:address), name: 'Harbour Hall')
      get show_path

      expect(page_html.at_css('#community-location.community-location').text).to include('Harbour Hall')
    end
  end

  describe 'a host override' do
    let(:override_dir) { Rails.root.join('tmp/community_show_hooks_views') }
    let(:original_paths) { BetterTogether::CommunitiesController.view_paths }

    before do
      dir = override_dir.join('better_together/communities')
      FileUtils.mkdir_p(dir)
      File.write(dir.join('_about_extra.html.erb'),
                 "<%# locals: (community:) -%>\n<p id=\"host-about-extra\"><%= community.name %></p>\n")
      File.write(dir.join('_header_media.html.erb'),
                 "<%# locals: (community:) -%>\n<div id=\"host-header-media\"></div>\n")
      original_paths
      BetterTogether::CommunitiesController.prepend_view_path(override_dir.to_s)
      get show_path
    end

    after do
      BetterTogether::CommunitiesController.view_paths = original_paths
      FileUtils.rm_rf(override_dir)
    end

    it 'replaces only the overridden partials', :aggregate_failures do
      expect(page_html.at_css('#host-about-extra').text).to eq(community.name)
      expect(page_html.at_css('#host-header-media')).to be_present
      expect(page_html.at_css('.cover-image-container')).to be_nil
      expect(page_html.at_css('#community-description')).to be_present
    end
  end
end
