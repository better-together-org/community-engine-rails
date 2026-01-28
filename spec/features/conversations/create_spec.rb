# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', :as_platform_manager, retry: 0 do
  include BetterTogether::ConversationHelpers
  include BetterTogether::CapybaraFeatureHelpers

  let!(:user) { create(:better_together_user, :confirmed) }

  before do
    configure_host_platform
    capybara_login_as_platform_manager

    # Ensure this person can be messaged by members so they appear in permitted_participants
    user.person.update!(
      privacy: 'public',
      preferences: (user.person.preferences || {}).merge('receive_messages_from_members' => true)
    )
  end

  scenario 'between a platform manager and normal user', :js do
    expect do
      create_conversation([user.person], first_message: Faker::Lorem.sentence(word_count: 8))
    end.to change(BetterTogether::Conversation, :count).by(1)
  end

  context 'as a normal user', :as_user do
    let!(:normal_user) { create(:better_together_user, :confirmed, email: 'user@example.test', password: 'SecureTest123!@#') }
    let(:user2) { create(:better_together_user) }

    before do
      # Ensure preferences are set for the normal user
      normal_user.person.update!(preferences: (normal_user.person.preferences || {}).merge('receive_messages_from_members' => true))
    end

    scenario 'can create a conversation with a public person who opted into messages', :js do
      target = create(:better_together_user, :confirmed)
      # Ensure target is public and opted-in to receive messages from members
      target.person.update!(privacy: 'public',
                            preferences: (target.person.preferences || {}).merge('receive_messages_from_members' => true)) # rubocop:disable Layout/LineLength

      expect do
        create_conversation([target.person], first_message: 'Hi there')
      end.to change(BetterTogether::Conversation, :count).by(1)
    end
    # rubocop:enable RSpec/ExampleLength

    it 'cannot create conversations with private users' do
      visit new_conversation_path(locale: I18n.default_locale)
      # Use proper Capybara matcher within select element
      within('select[name="conversation[participant_ids][]"]') do
        expect(page).not_to have_content(user2.person.name)
      end
    end
  end
end
