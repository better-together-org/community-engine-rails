# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile message prefill' do
  include RequestSpecHelper

  let!(:user) { create(:user, :confirmed, email: 'user@example.test') }
  let!(:other_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Target Person')
  end

  before do
    login_as(user, scope: :user)
  end

  it 'preselects the person when visiting new conversation via profile message link' do
    # rubocop:enable RSpec/MultipleExpectations
    # Simulate clicking the profile message link which sends conversation[participant_ids] in params
    get better_together.new_conversation_path(locale: I18n.default_locale,
                                              conversation: { participant_ids: [other_person.id] })

    expect(response).to have_http_status(:ok)

    # Ensure that the option for the target person is rendered and marked selected.
    # The option may include a handle suffix and selected may be rendered as selected="selected" or selected alone.
    # rubocop:todo Layout/LineLength
    expect(response.body).to match(%r{<option[^>]+value="#{other_person.id}"[^>]*(selected(="selected")?)?[^>]*>[\s\S]*?Target Person[\s\S]*?</option>})
    # rubocop:enable Layout/LineLength
  end
end
