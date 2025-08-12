# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'events index', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let!(:draft_event) { BetterTogether::Event.create!(name: 'Draft Event') }
  let!(:upcoming_event) { BetterTogether::Event.create!(name: 'Upcoming Event', starts_at: 1.day.from_now) }
  let!(:past_event) { BetterTogether::Event.create!(name: 'Past Event', starts_at: 2.days.ago) }

  scenario 'displays events grouped by status' do
    visit events_path(locale: I18n.default_locale)

    draft_section = find('h2', text: 'Draft').sibling('div')
    within(draft_section) do
      expect(page).to have_content(draft_event.name)
    end

    upcoming_section = find('h2', text: 'Upcoming').sibling('div')
    within(upcoming_section) do
      expect(page).to have_content(upcoming_event.name)
    end

    past_section = find('h2', text: 'Past').sibling('div')
    within(past_section) do
      expect(page).to have_content(past_event.name)
    end
  end
end
