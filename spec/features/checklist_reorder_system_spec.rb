# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Checklist reorder UX', :js do
  include ActionView::RecordIdentifier

  # Use the standard test manager credentials (password must meet length requirements)
  let(:manager) { find_or_create_test_user('manager@example.test', 'password12345', :platform_manager) }

  before do
    # Ensure essential data exists and log in
    ensure_essential_data!
    login_as(manager, scope: :user)
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'allows reordering items via move buttons (server-driven)' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    checklist = create(:better_together_checklist, title: 'Test Checklist')

    # Create three items
    3.times do |i|
      create(:better_together_checklist_item, checklist: checklist, position: i, label: "Item #{i + 1}")
    end

    visit better_together.checklist_path(checklist, locale: I18n.default_locale)

    # Wait for the checklist container and items to render
    expect(page).to have_selector("##{dom_id(checklist, :checklist_items)}", wait: 5)
    expect(page).to have_selector("##{dom_id(checklist, :checklist_items)} li.list-group-item", count: 3, wait: 5)

    # Find the rendered list items and click the move-up button for the second item
    within "##{dom_id(checklist, :checklist_items)}" do
      nodes = all('li.list-group-item')
      expect(nodes.size).to eq(3)

      # Click the move-up control for the second item (uses UJS/Turbo to issue PATCH)
      nodes[1].find('.keyboard-move-up').click
    end

    # Expect the UI to update: Item 2 should now be first in the list (wait for Turbo stream to apply)
    expect(page).to have_selector("##{dom_id(checklist, :checklist_items)} li.list-group-item:first-child",
                                  text: 'Item 2', wait: 5)

    # Now click move-down on what is currently the first item to move it back
    within "##{dom_id(checklist, :checklist_items)}" do
      nodes = all('li.list-group-item')
      nodes[0].find('.keyboard-move-down').click
    end

    # Expect the UI to reflect the original order again (wait for Turbo stream to apply)
    expect(page).to have_selector("##{dom_id(checklist, :checklist_items)} li.list-group-item:first-child",
                                  text: 'Item 1', wait: 5)
  end
end
