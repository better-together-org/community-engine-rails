# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StructuredDataHelper, type: :helper do
  let(:platform) { build(:platform, name: 'Platform', url: 'https://example.com') }
  let(:event) { BetterTogether::Event.new(name: 'Event', starts_at: Time.zone.parse('2024-01-01 12:00:00')) }

  before do
    allow(helper).to receive(:event_url).and_return('https://example.com/events/event')
  end

  describe '#structured_data_tag' do
    it 'wraps JSON-LD data in a script tag' do
      data = platform_structured_data(platform)
      html = structured_data_tag(data)
      expect(html).to include('application/ld+json')
      expect(html).to include('Platform')
    end
  end

  describe '#event_structured_data' do
    it 'includes event properties' do
      data = event_structured_data(event)
      expect(data[:name]).to eq('Event')
      expect(data[:url]).to eq('https://example.com/events/event')
      expect(data[:startDate]).to eq('2024-01-01T12:00:00Z')
    end
  end
end
