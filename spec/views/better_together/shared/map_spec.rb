# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_map' do
  let(:map) { build(:geography_map) }

  def render_map(**locals)
    render partial: 'better_together/shared/map', locals: { map: }.merge(locals)
    Nokogiri::HTML.fragment(rendered).at_css('div.map')
  end

  it 'renders nothing without a map' do
    render partial: 'better_together/shared/map', locals: { map: nil }

    expect(rendered.strip).to be_empty
  end

  it 'attaches the map controller with its data values and defaults', :aggregate_failures do
    element = render_map

    expect(element['data-controller']).to eq('better_together--map')
    expect(element['data-better_together--map-zoom-value']).to eq(map.zoom.to_s)
    expect(element['data-better_together--map-cluster-value']).to eq('true')
    expect(JSON.parse(element['data-better_together--map-types-value'])).to eq([])
    expect(element['data-better_together--map-boundary-value']).to be_nil
  end

  it 'passes translated labels to the controller', :aggregate_failures do
    labels = JSON.parse(render_map['data-better_together--map-labels-value'])

    expect(labels).to include('denied' => I18n.t('better_together.shared.map.geolocation.denied'),
                              'youAreHere' => I18n.t('better_together.shared.map.geolocation.you_are_here'))
    expect(labels.keys).to match_array(%w[locating located denied unavailable timeout unsupported youAreHere showOnMap])
  end

  it 'renders the three buttons as non-submitting buttons with translated text', :aggregate_failures do
    buttons = Nokogiri::HTML.fragment(rendered.presence || render_map.to_html).css('.map-controls button')

    expect(buttons.map { |b| b['type'] }).to all(eq('button'))
    expect(buttons.map(&:text)).to eq([I18n.t('better_together.shared.map.buttons.map'),
                                       I18n.t('better_together.shared.map.buttons.satellite'),
                                       I18n.t('better_together.shared.map.buttons.geolocate')])
  end

  it 'can turn clustering off, and pass types and a boundary', :aggregate_failures do
    boundary = { 'type' => 'Polygon', 'coordinates' => [[[0, 0], [1, 0], [1, 1], [0, 0]]] }
    types = [{ key: 'Event', label: 'Events', color: '#198754' }]

    element = render_map(cluster: false, types:, boundary:)

    expect(element['data-better_together--map-cluster-value']).to eq('false')
    expect(JSON.parse(element['data-better_together--map-types-value']).first).to include('key' => 'Event')
    expect(JSON.parse(element['data-better_together--map-boundary-value'])).to eq(boundary)
  end

  it 'lets a derived map add controllers and attributes without copying the partial', :aggregate_failures do
    element = render_map(extra_controllers: ['better_together--space-fields'],
                         attributes: { 'data-better_together--space-fields-target' => 'map', 'class' => 'map extra' })

    expect(element['data-controller']).to eq('better_together--map better_together--space-fields')
    expect(element['data-better_together--space-fields-target']).to eq('map')
    expect(element['class']).to eq('map extra')
  end
end
