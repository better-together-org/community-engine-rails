# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversation client-side validation', :js do
  include Capybara::DSL

  let!(:user) { create(:user, :confirmed, email: 'feature_user@example.test') }
  let!(:other_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Target Person')
  end

  before do
    login_as(user, scope: :user)
  end

  # rubocop:todo RSpec/ExampleLength
  # rubocop:todo RSpec/MultipleExpectations
  it 'prevents submission and shows client-side validation when first message is empty' do
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.new_conversation_path(locale: I18n.default_locale,
                                                conversation: { participant_ids: [other_person.id] })

    # Attempt to submit the form (use a robust selector for submit button)
    form = page.find('form')
    submit = form.first(:button, type: 'submit') || form.first(:xpath, ".//input[@type='submit']")
    submit.click

    # The JS form-validation controller should mark the message field invalid
    # Look for an element with is-invalid class near trix-editor
    expect(page).to have_selector('.trix-editor.is-invalid, .is-invalid', wait: 5)

    # Ensure we are still on the new conversation form (no redirect)
    expect(page).to have_current_path(%r{/conversations/new}, ignore_query: true)
  end
  # rubocop:enable RSpec/ExampleLength
end
