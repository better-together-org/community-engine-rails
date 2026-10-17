# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/geography/spaces/_fields' do
  let(:space) { BetterTogether::Geography::Space.new }

  def render_fields
    render inline: <<~ERB, locals: { space: }
      <%= form_with(model: space, url: '/spaces') { |form| render 'better_together/geography/spaces/fields', form: form } %>
    ERB
    Nokogiri::HTML.fragment(rendered)
  end

  it 'renders the shared map wired to the coordinate fields, without clustering', :aggregate_failures do
    element = render_fields.at_css('div.map')

    expect(element['data-controller']).to eq('better_together--map')
    expect(element['data-better_together--space-fields-target']).to eq('map')
    expect(element['data-better_together--map-cluster-value']).to eq('false')
  end

  it 'keeps the coordinate inputs the space-fields controller targets', :aggregate_failures do
    fragment = render_fields

    expect(fragment.at_css('input[data-better_together--space-fields-target="latitude"]')).to be_present
    expect(fragment.at_css('input[data-better_together--space-fields-target="longitude"]')).to be_present
  end

  it 'uses buttons that do not submit the surrounding form' do
    types = render_fields.css('.map-controls button').map { |button| button['type'] }

    expect(types).to eq(%w[button button button])
  end
end
