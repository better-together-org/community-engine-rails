# frozen_string_literal: true

require 'rails_helper'

# Date and time, then location, in the show header, the About pane and the event card;
# in About the register link sits between privacy and the date and time.
RSpec.describe 'Event detail ordering', type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let!(:event) do
    create(:better_together_event, :with_simple_location, privacy: 'public', starts_at: 3.days.from_now,
                                                          ends_at: 3.days.from_now + 1.hour,
                                                          registration_url: 'https://tickets.example.test/night')
  end

  before { configure_host_platform }

  def in_order?(scope, selectors)
    nodes = scope.css(selectors.join(', ')).to_a
    selectors.map { |css| nodes.index(scope.at_css(css)) }.each_cons(2).all? { |a, b| a && b && a < b }
  end

  it 'orders the show header' do
    get better_together.event_path(event, locale:)
    header = Nokogiri::HTML(response.body).at_css('.event-info-container')

    expect(in_order?(header, ['.event-datetime', '.event-location'])).to be(true)
  end

  it 'orders the About pane' do
    get better_together.event_path(event, locale:)
    about = Nokogiri::HTML(response.body).at_css('#about')

    expect(in_order?(about, ['.fa-eye', '.fa-ticket', '.fa-calendar-alt', '.event-location'])).to be(true)
  end

  it 'orders the event card' do
    get better_together.events_path(locale:)
    card = Nokogiri::HTML(response.body).at_css('.event-card')

    expect(in_order?(card, ['.event-datetime', '.event-location'])).to be(true)
  end
end
