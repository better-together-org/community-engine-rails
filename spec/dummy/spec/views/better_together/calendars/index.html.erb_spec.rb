# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/calendars/index', type: :view do
  before(:each) do
    assign(:better_together_calendars, [
             BetterTogether::Calendar.create!(
               identifier: 'Identifier',
               name: 'Name',
               description: 'MyText',
               slug: 'Slug',
               privacy: 'Privacy',
               protected: false
             ),
             BetterTogether::Calendar.create!(
               identifier: 'Identifier',
               name: 'Name',
               description: 'MyText',
               slug: 'Slug',
               privacy: 'Privacy',
               protected: false
             )
           ])
  end

  it 'renders a list of better_together/calendars' do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new('Identifier'), count: 2
    assert_select cell_selector, text: Regexp.new('Name'), count: 2
    assert_select cell_selector, text: Regexp.new('MyText'), count: 2
    assert_select cell_selector, text: Regexp.new('Slug'), count: 2
    assert_select cell_selector, text: Regexp.new('Privacy'), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
  end
end
