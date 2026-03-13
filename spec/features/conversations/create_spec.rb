# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', retry: 0 do
  include BetterTogether::ConversationHelpers
  include BetterTogether::CapybaraFeatureHelpers

  let!(:user) { create(:better_together_user, :confirmed) }

  before do
    configure_host_platform
    # Ensure this person can be messaged by members so they appear in permitted_participants
    user.person.reload.update!(preferences: (user.person.preferences || {}).merge('receive_messages_from_members' => true))
  end

  context 'as a platform manager', :as_platform_manager do
    before do
      capybara_login_as_platform_manager
    end

    scenario 'between a platform manager and normal user', :js do
      # Ensure user record is visible to application server
      ensure_record_visible(user)
      ensure_record_visible(user.person)

      expect do
        create_conversation([user.person], first_message: Faker::Lorem.sentence(word_count: 8))
      end.to change(BetterTogether::Conversation, :count).by(1)
    end
  end

  context 'as a normal user', :as_user do
    let!(:normal_user) do
      user = BetterTogether::User.find_by(email: 'user@example.test') ||
             create(:better_together_user, :confirmed, email: 'user@example.test', password: 'SecureTest123!@#')
      ensure_record_visible(user) if defined?(ensure_record_visible)
      ensure_record_visible(user.person) if defined?(ensure_record_visible)
      user
    end
    let(:user2) do
      user = create(:better_together_user)
      ensure_record_visible(user) if defined?(ensure_record_visible)
      ensure_record_visible(user.person) if defined?(ensure_record_visible)
      user
    end

    before do
      normal_user # Ensure user exists before login
      capybara_login_as_user
    end

    scenario 'can create a conversation with a public person who opted into messages', :js do
      target = create(:better_together_user, :confirmed)
      # Ensure target is public and opted-in to receive messages from members
      target.person.reload.update!(privacy: 'public',
                                   preferences: (target.person.preferences || {}).merge('receive_messages_from_members' => true)) # rubocop:disable Layout/LineLength

      # Ensure record is visible to application server before creating conversation
      ensure_record_visible(target)
      ensure_record_visible(target.person)

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
