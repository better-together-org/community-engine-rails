# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationItemsHelper, '#dropdown_aria_attributes' do
  it 'exposes real aria attributes for an item with children' do
    item = instance_double(BetterTogether::NavigationItem, children?: true)

    expect(helper.dropdown_aria_attributes(item)).to eq(expanded: 'false', haspopup: 'true')
  end

  it 'adds nothing for a leaf item' do
    item = instance_double(BetterTogether::NavigationItem, children?: false)

    expect(helper.dropdown_aria_attributes(item)).to eq({})
  end

  it 'keeps aria-expanded out of the data attributes' do
    item = instance_double(BetterTogether::NavigationItem, children?: true, identifier: 'x', slug: 'x', id: 'abc')
    allow(helper).to receive_messages(navigation_item_turbo_frame_target: nil, dom_id: 'x_1')

    expect(helper.dropdown_data_attributes(item).keys).not_to include('aria-expanded')
  end
end
