# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/calendars/edit', type: :view do
  let(:better_together_calendar) do
    BetterTogether::Calendar.create!(
      identifier: 'MyString',
      name: 'MyString',
      description: 'MyText',
      slug: 'MyString',
      privacy: 'MyString',
      protected: false
    )
  end

  before(:each) do
    assign(:better_together_calendar, better_together_calendar)
  end

  it 'renders the edit better_together_calendar form' do
    render

    assert_select 'form[action=?][method=?]', better_together_calendar_path(better_together_calendar), 'post' do
      assert_select 'input[name=?]', 'better_together_calendar[identifier]'

      assert_select 'input[name=?]', 'better_together_calendar[name]'

      assert_select 'textarea[name=?]', 'better_together_calendar[description]'

      assert_select 'input[name=?]', 'better_together_calendar[slug]'

      assert_select 'input[name=?]', 'better_together_calendar[privacy]'

      assert_select 'input[name=?]', 'better_together_calendar[protected]'
    end
  end
end
