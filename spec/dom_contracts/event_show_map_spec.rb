# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the event page: the map sits in a column beside the tabs once the event is located at a
# geocoded place, and the description is a div so rich text can hold block elements.
RSpec.describe 'Event show map DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:event) do
    create(:better_together_event, :with_address_location, creator: create(:person), privacy: 'public',
                                                           name: 'Harbour Meetup')
  end
  let(:page_html) { Nokogiri::HTML(response.body) }

  def show_path
    "/#{I18n.default_locale}/events/#{event.slug}"
  end

  def geocode!
    create(:geography_geospatial_space, geospatial: event.location.location, space: create(:geography_space))
  end

  it 'keeps the description in a div for rich text', :aggregate_failures do
    get show_path

    expect(page_html.at_css('#event-description').name).to eq('div')
    expect(page_html.css('p#event-description')).to be_empty
  end

  it 'has no map when the event has no location', :aggregate_failures do
    event.location&.destroy
    event.reload
    get show_path

    expect(page_html.at_css('#event-map')).to be_nil
    expect(page_html.at_css('#event-tabbed-section').parent['class']).not_to include('col-lg-6')
  end

  it 'puts the map beside the tabs when the event is geocoded', :aggregate_failures do
    geocode!
    get show_path

    map = page_html.at_css('#event-map')
    expect(map).to be_present
    expect(map['class']).to include('event-map', 'col-lg-6', 'col-xl-4')
    expect(map['aria-label']).to include('Harbour Meetup')
    expect(page_html.at_css('#event-tabbed-section').parent['class']).to include('col-lg-6', 'col-xl-8')
  end

  it 'does not repeat the map inside the about pane' do
    geocode!
    get show_path

    expect(page_html.css('.event-map').size).to eq(1)
  end
end
