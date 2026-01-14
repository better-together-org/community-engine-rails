# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', :as_platform_manager do
  include BetterTogether::ConversationHelpers

  let!(:user) { create(:better_together_user, :confirmed) }

  before do
    # Ensure this person can be messaged by members so they appear in permitted_participants
    user.person.update!(preferences: (user.person.preferences || {}).merge('receive_messages_from_members' => true))
  end

  scenario 'between a platform manager and normal user', :js do
    create_conversation([user.person], first_message: Faker::Lorem.sentence(word_count: 8))
    expect(BetterTogether::Conversation.count).to eq(1)
  end

  context 'as a normal user' do
    before do
      sign_in_user(user.email, user.password)
    end

    let(:user2) { create(:better_together_user) }

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
