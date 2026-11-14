# frozen_string_literal: true

require 'rails_helper'

# The shared map partial validates pin data before it reaches the browser.
RSpec.describe 'better_together/shared/_map pins' do
  let(:map) do
    instance_double(BetterTogether::Geography::Map, center_for_leaflet: '48.9,-57.9', zoom: 8, viewport: nil, layers: [],
                                                    leaflet_points: [{ lat: 1, lng: 2, color: 'red;x:y',
                                                                       pin: { icons: ['fa-star', 'fa-x" y'] } }])
  end
  let(:types) { [{ key: 'Venue', label: 'Venues', color: '#198754', pin: { shape: 'rounded', icons: ['<b>'] } }] }
  let(:json) { ->(name) { JSON.parse(CGI.unescapeHTML(rendered[/data-better_together--map-#{name}-value="([^"]*)"/, 1])) } }

  before do
    allow(map).to receive(:to_model).and_return(map)
    allow(map).to receive_messages(model_name: ActiveModel::Name.new(BetterTogether::Geography::Map), to_key: [1],
                                   persisted?: true, to_param: '1')
    render partial: 'better_together/shared/map', locals: { map:, types: }
  end

  it 'sends only valid icons in a point pin' do
    expect(json.call('spaces').first['pin']).to eq('icons' => [{ 'icon' => 'fa-star', 'style' => 'fas' }])
  end

  it 'sends a type pin with unusable icons without them' do
    expect(json.call('types').first['pin']).to eq('shape' => 'rounded')
  end
end
