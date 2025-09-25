# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Person completes checklist', :js do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let!(:person) { create(:better_together_person, user: user) }

  before do
    find_or_create_test_user('user@example.test', 'password12345', :user)
    capybara_login_as_user
  end

  # rubocop:todo RSpec/PendingWithoutReason
  # rubocop:todo RSpec/MultipleExpectations
  xit 'allows a person to complete all items and shows completion message' do # rubocop:todo RSpec/MultipleExpectations, RSpec/PendingWithoutReason
    # rubocop:enable RSpec/MultipleExpectations
    # rubocop:enable RSpec/PendingWithoutReason
    checklist = create(:better_together_checklist, privacy: 'public')
    create_list(:better_together_checklist_item, 5, checklist: checklist)

    events = []
    subscriber = ActiveSupport::Notifications.subscribe('better_together.checklist.completed') do |*args|
      events << args
    end

    visit better_together.checklist_path(checklist, locale: I18n.default_locale)

    # Click each checkbox to mark done (scope to the list group)
    within 'ul.list-group' do
      all('li.list-group-item').each do |li|
        li.find('.checklist-checkbox').click
      end
    end

    # Expect completion message to appear
    expect(page).to have_selector('.alert.alert-success', text: 'Checklist complete')

    # Event was fired
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(events).not_to be_empty
  end
end
