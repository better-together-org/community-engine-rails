# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/calendars/show', type: :view do
  before do
  end

  before(:each) do
    calendar = create(:better_together_calendar)
    assign(:calendar, calendar)
    allow(view).to receive(:policy).with(calendar).and_return(BetterTogether::CalendarPolicy.new(
                                                                build(:better_together_user), calendar
                                                              ))
  end

  it 'renders attributes in <p>' do
    render
    expect(rendered).to match(/Identifier/)
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/Slug/)
    expect(rendered).to match(/private/)
    expect(rendered).to match(/false/)
  end
end
