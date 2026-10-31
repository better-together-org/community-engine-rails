# frozen_string_literal: true

require 'rails_helper'

# A community is shown by its logo, else its profile image (never both), on cards, host mentions, chips and the
# host picker.
RSpec.describe 'Community marks DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20"><rect width="40" height="20"/></svg>' }
  let(:page_html) { Nokogiri::HTML(response.body) }

  def community_with(*names)
    create(:better_together_community, privacy: 'public').tap do |community|
      names.each do |name|
        community.public_send(name).attach(io: StringIO.new(svg), filename: "#{name}.svg", content_type: 'image/svg+xml')
      end
    end
  end

  def hosted_event(community)
    create(:better_together_event, privacy: 'public', starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours,
                                   event_hosts_attributes: [{ host_type: 'BetterTogether::Community',
                                                              host_id: community.id }])
  end

  def visit_path(path)
    get "/#{I18n.default_locale}#{path}"
  end

  describe 'community card' do
    it 'shows the logo as a tile over the cover', :aggregate_failures do
      community = community_with(:cover_image, :logo, :profile_image)
      visit_path('/communities')

      mark = page_html.css("#card_mark_community_#{community.id}")
      expect(mark.size).to eq(1)
      expect(mark.first['class']).to include('community-card-mark', 'community-card-mark--cover')
    end

    it 'falls back to the profile image, and shows no mark with neither', :aggregate_failures do
      with_profile = community_with(:cover_image, :profile_image)
      bare = community_with(:cover_image)
      visit_path('/communities')

      expect(page_html.at_css("#card_mark_community_#{with_profile.id}")).to be_present
      expect(page_html.at_css("#card_mark_community_#{bare.id}")).to be_nil
    end

    it 'puts the mark in place of the cover when there is no cover', :aggregate_failures do
      community = community_with(:logo)
      visit_path('/communities')

      expect(page_html.at_css("#community_#{community.id} .community-card--mark-only")).to be_present
      expect(page_html.at_css('.community-card-mark--cover')).to be_nil
    end
  end

  describe 'event card host mention' do
    it 'shows a logo as a tile with no round avatar', :aggregate_failures do
      event = hosted_event(community_with(:logo, :profile_image))
      visit_path('/events')

      card = page_html.at_css("#event_#{event.id}")
      expect(card.at_css('.community-mark-tile')).to be_present
      expect(card.at_css('img.event-host-avatar')).to be_nil
    end

    it 'shows the round profile image when there is no logo', :aggregate_failures do
      event = hosted_event(community_with(:profile_image))
      visit_path('/events')

      card = page_html.at_css("#event_#{event.id}")
      expect(card.at_css('img.event-host-avatar.rounded-circle')).to be_present
      expect(card.at_css('.community-mark-tile')).to be_nil
    end
  end

  describe 'host picker' do
    it 'shows the existing host logo tile in the edit form' do
      event = hosted_event(community_with(:logo))
      visit_path("/events/#{event.slug}/edit")

      expect(page_html.at_css('.community-mark-tile')).to be_present
    end
  end

  describe 'community chip' do
    it 'shows the logo tile on a post card' do
      create(:better_together_post, community: community_with(:logo), privacy: 'public', published_at: 1.day.ago)
      visit_path('/posts')

      expect(page_html.at_css('.community-chip .community-mark-tile')).to be_present
    end
  end
end
