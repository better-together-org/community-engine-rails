# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::MapLayer do
  after { described_class.clear_registry! }

  let(:attributes) do
    { label: 'Districts', attribution: 'Electoral Boundaries Commission', attribution_url: 'https://example.test/src',
      licence: 'Open Government Licence', licence_url: 'https://example.test/ogl', url: '/districts.geojson' }
  end

  it 'builds an escaped credit line with links for the source and the licence' do
    html = described_class.new(key: 'districts', **attributes).attribution_html

    expect(html).to eq('<a href="https://example.test/src" target="_blank" rel="noopener">' \
                       'Electoral Boundaries Commission</a> (<a href="https://example.test/ogl" target="_blank" ' \
                       'rel="noopener">Open Government Licence</a>)')
  end

  it 'escapes text and drops links that are not http(s)', :aggregate_failures do
    html = described_class.new(key: 'x', attribution: '<b>Data</b>', attribution_url: 'javascript:alert(1)').attribution_html

    expect(html).to eq('&lt;b&gt;Data&lt;/b&gt;')
    expect(html).not_to include('<a')
  end

  it 'serialises for the map controller without empty keys', :aggregate_failures do
    json = described_class.new(key: 'districts', **attributes).as_json

    expect(json).to include('key' => 'districts', 'label' => 'Districts', 'url' => '/districts.geojson')
    expect(json).not_to have_key('geojson')
    expect(json['style']).to include('color' => '#0d6efd')
  end

  it 'resolves registered keys, hashes and layers, skipping unknown keys and duplicates' do
    described_class.register(:districts, **attributes)
    layer = described_class.new(key: 'own', attribution: 'Own')

    resolved = described_class.resolve(:districts, 'districts', { key: 'inline', attribution: 'Inline' }, layer, :nope)

    expect(resolved.map(&:key)).to eq(%w[districts inline own])
  end
end
