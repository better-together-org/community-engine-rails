# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Conversations' do
  include RequestSpecHelper

  before do
    configure_host_platform
  end

  let!(:manager_user) do
    create(:user, :confirmed, :platform_manager, email: 'manager1@example.test', password: 'password12345')
  end
  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Opted In User')
  end
  let!(:non_opted_person) { create(:better_together_person, name: 'Non Opted User') }

  describe 'GET /conversations/new' do
    context 'as a regular member' do
      let!(:regular_user) { create(:user, :confirmed, email: 'user@example.test', password: 'password12345') }

      before do
        login(regular_user.email, 'password12345')
      end

      it 'lists platform managers and opted-in members, but excludes non-opted members' do
        get better_together.new_conversation_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:ok)
        # Includes manager and opted-in person in the select options
        expect(response.body).to include(manager_user.person.name)
        expect(response.body).to include('Opted In User')
        # Excludes non-opted person
        expect(response.body).not_to include('Non Opted User')
      end
    end

    context 'as a platform manager' do
      before do
        login(manager_user.email, 'password12345')
      end

      it 'lists all people as available participants' do
        get better_together.new_conversation_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(manager_user.person.name)
        expect(response.body).to include('Opted In User')
        expect(response.body).to include('Non Opted User')
      end
    end
  end

  describe 'POST /conversations' do
    context 'as a regular member' do
      let!(:regular_user) { create(:user, :confirmed, email: 'user2@example.test', password: 'password12345') }

      before { login(regular_user.email, 'password12345') }

      it 'filters out non-permitted participant_ids on create' do
        post better_together.conversations_path(locale: I18n.default_locale), params: {
          conversation: {
            title: 'Hello',
            participant_ids: [opted_in_person.id, non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:found)
        convo = BetterTogether::Conversation.order(created_at: :desc).first
        expect(convo.creator).to eq(regular_user.person)
        ids = convo.participants.pluck(:id)
        expect(ids).to include(regular_user.person.id) # creator always added
        expect(ids).to include(opted_in_person.id)     # allowed
        expect(ids).not_to include(non_opted_person.id) # filtered out
      end

      it 'shows an error when only non-permitted participants are submitted' do
        before_count = BetterTogether::Conversation.count
        post better_together.conversations_path(locale: I18n.default_locale), params: {
          conversation: {
            title: 'Hello',
            participant_ids: [non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:ok)
        expect(BetterTogether::Conversation.count).to eq(before_count)
        expect(response.body).to include(I18n.t('better_together.conversations.errors.no_permitted_participants'))
      end
    end
  end

  describe 'PATCH /conversations/:id' do
    context 'as a regular member' do
      let!(:regular_user) { create(:user, :confirmed, email: 'user3@example.test', password: 'password12345') }
      let!(:conversation) do
        create('better_together/conversation', creator: regular_user.person).tap do |c|
          c.participants << regular_user.person unless c.participants.exists?(regular_user.person.id)
        end
      end

      before { login(regular_user.email, 'password12345') }

      it 'does not add non-permitted participants on update' do
        patch better_together.conversation_path(conversation, locale: I18n.default_locale), params: {
          conversation: {
            title: conversation.title,
            participant_ids: [regular_user.person.id, non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:found)
        conversation.reload
        ids = conversation.participants.pluck(:id)
        expect(ids).to include(regular_user.person.id)
        expect(ids).not_to include(non_opted_person.id)
      end

      it 'shows an error when update attempts to add only non-permitted participants' do
        patch better_together.conversation_path(conversation, locale: I18n.default_locale), params: {
          conversation: {
            title: conversation.title,
            participant_ids: [non_opted_person.id]
          }
        }
        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(response.body).to include(I18n.t('better_together.conversations.errors.no_permitted_participants'))
      end
    end
  end
end
