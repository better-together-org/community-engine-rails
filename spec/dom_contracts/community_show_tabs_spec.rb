# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the community page: tabs driven by the tabs controller, lazy frames for posts and events, the
# contact tab, and the map beside the tabs once the community is located at a geocoded place.
RSpec.describe 'Community show tabs DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:community) { create(:community, creator: create(:person), privacy: 'public') }
  let(:page_html) { Nokogiri::HTML(response.body) }
  let(:contact) { { email_addresses: [{ email: 'hello@harbour.example', label: 'General' }] }.to_json }

  def show_path
    "/#{I18n.default_locale}/c/#{community.slug}"
  end

  def locate_with_map
    address = create(:address)
    create(:geography_geospatial_space, geospatial: address,
                                        space: create(:geography_space, latitude: 48.95, longitude: -57.95))
    community.create_location!(location: address, name: 'Harbour Hall')
  end

  describe 'tab markup' do
    before do
      community.update!(contact_spec: contact)
      get show_path
    end

    it 'puts the tabs controller on the tabbed section', :aggregate_failures do
      section = page_html.at_css('#community-tabbed-section')
      expect(section['data-controller']).to eq('better_together--tabs')
      expect(page_html.css('#communityTabs [data-better_together--tabs-target="tab"]').size)
        .to eq(page_html.css('#communityTabs a.nav-link').size)
    end

    it 'links every tab to a tab pane by id', :aggregate_failures do
      page_html.css('#communityTabs a.nav-link').each do |tab|
        pane = page_html.at_css(tab['data-bs-target'])
        expect(pane).to be_present
        expect(pane['class']).to include('tab-pane')
        expect(tab['aria-controls']).to eq(pane['id'])
        expect(pane['aria-labelledby']).to eq(tab['id'])
      end
    end

    it 'activates exactly the about tab and pane', :aggregate_failures do
      expect(page_html.css('#communityTabs a.active').pluck('id')).to eq(['about-tab'])
      expect(page_html.css('.tab-pane.active').pluck('id')).to eq(['about'])
    end

    it 'has no inline hash script', :aggregate_failures do
      expect(response.body).not_to include('shown.bs.tab')
      expect(response.body).not_to include('window.location.hash = ')
    end

    it 'shows the contact details in their own tab', :aggregate_failures do
      expect(page_html.at_css('#contact-tab')).to be_present
      expect(page_html.at_css('#contact').text).to include('hello@harbour.example')
      expect(page_html.at_css('#about').text).not_to include('hello@harbour.example')
    end

    it 'keeps the description in a div for rich text', :aggregate_failures do
      expect(page_html.at_css('#community-description').name).to eq('div')
      expect(page_html.css('p#community-description')).to be_empty
    end
  end

  describe 'without contact details' do
    it 'has no contact tab' do
      get show_path

      expect(page_html.at_css('#contact-tab')).to be_nil
    end
  end

  describe 'posts and events frames' do
    it 'loads each index lazily, breaking out of the frame for links', :aggregate_failures do
      get show_path

      %w[posts events].each do |name|
        frame = page_html.at_css("##{name} turbo-frame")
        expect(frame['id']).to eq("community-#{name}")
        expect(frame.attributes.transform_values(&:value)).to include('loading' => 'lazy', 'target' => '_top')
        expect(frame['src']).to include("community_id=#{community.slug}")
      end
    end
  end

  describe 'the map' do
    it 'is absent when the community has no geocoded place', :aggregate_failures do
      get show_path

      expect(page_html.at_css('#community-map')).to be_nil
      expect(page_html.at_css('#community-tabbed-section').parent['class']).not_to include('col-lg-6')
    end

    it 'sits beside the tabs when the community is located at a geocoded place', :aggregate_failures do
      locate_with_map
      get show_path

      expect(page_html.at_css('#community-map')).to be_present
      expect(page_html.at_css('#community-tabbed-section').parent['class']).to include('col-lg-6')
      expect(page_html.at_css('#community-location').text).to include('Harbour Hall')
    end
  end
end
