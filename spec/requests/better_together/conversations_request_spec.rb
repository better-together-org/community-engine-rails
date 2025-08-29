# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Conversations', :as_user do
  include RequestSpecHelper

  let!(:manager_user) do
    create(:user, :confirmed, :platform_manager, email: 'manager1@example.test', password: 'password12345')
  end
  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Opted In User')
  end
  let!(:non_opted_person) { create(:better_together_person, name: 'Non Opted User') }

  describe 'GET /conversations/new' do
    context 'as a regular member', :as_user do # rubocop:todo RSpec/ContextWording
      # rubocop:todo RSpec/MultipleExpectations
      it 'lists platform managers and opted-in members, but excludes non-opted members' do
        # rubocop:enable RSpec/MultipleExpectations
        get better_together.new_conversation_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:ok)
        # Includes manager and opted-in person in the select options
        expect(response.body).to include(manager_user.person.name)
        expect(response.body).to include('Opted In User')
        # Excludes non-opted person
        expect(response.body).not_to include('Non Opted User')
      end
    end

    context 'as a platform manager', :as_platform_manager do # rubocop:todo RSpec/ContextWording
      it 'lists all people as available participants' do # rubocop:todo RSpec/MultipleExpectations
        get better_together.new_conversation_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(manager_user.person.name)
        expect(response.body).to include('Opted In User')
        expect(response.body).to include('Non Opted User')
      end
    end
  end

  describe 'POST /conversations' do
    context 'as a regular member', :as_user do # rubocop:todo RSpec/ContextWording
      # rubocop:todo RSpec/ExampleLength
      # rubocop:todo RSpec/MultipleExpectations
      it 'creates conversation with permitted participants (opted-in) and excludes non-permitted' do
        # rubocop:enable RSpec/MultipleExpectations
        post better_together.conversations_path(locale: I18n.default_locale), params: {
          conversation: {
            title: 'Hello',
            participant_ids: [opted_in_person.id, non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:found)
        # Do not follow redirect here; just check DB state
        convo = BetterTogether::Conversation.order(created_at: :desc).first
        user = BetterTogether::User.find_by(email: 'user@example.test')
        expect(convo.creator).to eq(user.person)
        ids = convo.participants.pluck(:id)
        expect(ids).to include(user.person.id) # creator always added
        expect(ids).to include(opted_in_person.id) # allowed
        expect(ids).not_to include(non_opted_person.id) # filtered out
      end
      # rubocop:enable RSpec/ExampleLength

      # rubocop:todo RSpec/MultipleExpectations
      it 'shows an error when only non-permitted participants are submitted' do # rubocop:todo RSpec/ExampleLength
        # rubocop:enable RSpec/MultipleExpectations
        before_count = BetterTogether::Conversation.count
        post better_together.conversations_path(locale: I18n.default_locale), params: {
          conversation: {
            title: 'Hello',
            participant_ids: [non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(BetterTogether::Conversation.count).to eq(before_count)
        expect(response.body).to include(I18n.t('better_together.conversations.errors.no_permitted_participants'))
      end
    end
  end

  describe 'PATCH /conversations/:id' do
    context 'as a regular member', :as_user do # rubocop:todo RSpec/ContextWording
      let!(:conversation) do
        # Ensure the conversation reflects policy by using the logged-in user's person
        user = BetterTogether::User.find_by(email: 'user@example.test')
        create('better_together/conversation', creator: user.person).tap do |c|
          c.participants << user.person unless c.participants.exists?(user.person.id)
        end
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'does not add non-permitted participants on update' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        user = BetterTogether::User.find_by(email: 'user@example.test')
        patch better_together.conversation_path(conversation, locale: I18n.default_locale), params: {
          conversation: {
            title: conversation.title,
            participant_ids: [user.person.id, non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:found)
        conversation.reload
        ids = conversation.participants.pluck(:id)
        expect(ids).to include(user.person.id)
        expect(ids).not_to include(non_opted_person.id)
      end

      # rubocop:todo RSpec/ExampleLength
      # rubocop:todo RSpec/MultipleExpectations
      it 'shows an error when update attempts to add only non-permitted participants' do
        # rubocop:enable RSpec/MultipleExpectations
        patch better_together.conversation_path(conversation, locale: I18n.default_locale), params: {
          conversation: {
            title: conversation.title,
            participant_ids: [non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t('better_together.conversations.errors.no_permitted_participants'))
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
