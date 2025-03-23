# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/calendars/new', type: :view do
  # before(:each) do
  #   assign(:better_together_calendar, BetterTogether::Calendar.new(
  #                                       identifier: 'MyString',
  #                                       name: 'MyString',
  #                                       description: 'MyText',
  #                                       slug: 'MyString',
  #                                       privacy: 'MyString',
  #                                       protected: false
  #                                     ))
  # end

  # it 'renders new better_together_calendar form' do
  #   render

  #   assert_select 'form[action=?][method=?]', better_together_calendars_path, 'post' do
  #     assert_select 'input[name=?]', 'better_together_calendar[identifier]'

  #     assert_select 'input[name=?]', 'better_together_calendar[name]'

  #     assert_select 'textarea[name=?]', 'better_together_calendar[description]'

  #     assert_select 'input[name=?]', 'better_together_calendar[slug]'

  #     assert_select 'input[name=?]', 'better_together_calendar[privacy]'

  #     assert_select 'input[name=?]', 'better_together_calendar[protected]'
  #   end
  # end
end
