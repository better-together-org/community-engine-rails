# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Checklist item creation appends to bottom', :js do
  include ActionView::RecordIdentifier

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }

  before do
    ensure_essential_data!
    login_as(manager, scope: :user)
  end

  it 'creates a new checklist item and it appears at the bottom after refresh' do
    # rubocop:enable RSpec/MultipleExpectations
    checklist = create(:better_together_checklist, title: 'Append Test Checklist')

    # Create five existing items with positions 0..4
    5.times do |i|
      create(:better_together_checklist_item, checklist: checklist, position: i, label: "Existing #{i + 1}")
    end

    visit better_together.checklist_path(checklist, locale: I18n.default_locale)

    list_selector = "##{dom_id(checklist, :checklist_items)}"

    # sanity: we have 5 items initially
    expect(page).to have_selector("#{list_selector} li.list-group-item", count: 5, wait: 5)

    # Fill the new item form (uses the stable new_checklist_item turbo frame + form)
    within '#new_checklist_item' do
      fill_in 'checklist_item[label]', with: 'Appended Item'
      # privacy defaults to public; submit the form
      click_button I18n.t('globals.create', default: 'Create')
    end

    # Wait for Turbo to append the new item (should now be 6)
    expect(page).to have_selector("#{list_selector} li.list-group-item", count: 6, wait: 5)

    # Verify server-side persisted ordering (Positioned concern should have set position)
    checklist.reload
    last_record = checklist.checklist_items.order(:position).last
    expect(last_record.label).to eq('Appended Item')

    # Reload the page to ensure persistent ordering from the server and also verify UI shows it
    visit current_path
    within list_selector do
      last_li = all('li.list-group-item').last
      expect(last_li).to have_text('Appended Item')
    end
  end
end
