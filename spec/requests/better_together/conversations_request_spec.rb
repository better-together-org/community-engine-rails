# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Conversations' do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }
  let!(:other_platform) { create(:better_together_platform) }

  let!(:regular_user) do
    create(:user, :confirmed, email: 'member@example.test', password: 'SecureTest123!@#',
                              person_attributes: { name: 'Regular Member' })
  end
  let!(:manager_user) do
    create(:user, :confirmed, email: 'manager1@example.test', password: 'SecureTest123!@#',
                              person_attributes: { name: "Manager O'Connor" })
  end
  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: "Opted In O'Reilly")
  end
  let!(:non_opted_person) { create(:better_together_person, name: "Non Opted O'Neil") }
  let!(:other_platform_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Other Platform Person')
  end
  let!(:host_only_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Host Community Person')
  end

  before do
    manage_platform_permission = BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform')
    steward_role = create(:better_together_role, :platform_role)
    BetterTogether::RoleResourcePermission.create!(role: steward_role, resource_permission: manage_platform_permission)

    create(:better_together_person_platform_membership, member: regular_user.person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: manager_user.person, joinable: host_platform, role: steward_role)
    create(:better_together_person_platform_membership, member: opted_in_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: non_opted_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: other_platform_opted_in_person, joinable: other_platform)
    create(:better_together_person_community_membership, member: host_only_opted_in_person, joinable: host_platform.community)
  end

  describe 'GET /conversations/new' do
    before { login(current_user.email, 'SecureTest123!@#') }

    context 'as a regular member' do
      let(:current_user) { regular_user }

      it 'lists current-platform stewards and opted-in members only' do
        get better_together.new_conversation_path(locale: I18n.default_locale)

        expect(response).to have_http_status(:ok)
        expect(participant_option_labels).to include(
          manager_user.person.select_option_title,
          opted_in_person.select_option_title,
          host_only_opted_in_person.select_option_title
        )
        expect(participant_option_labels).not_to include(non_opted_person.select_option_title)
        expect(participant_option_labels).not_to include(other_platform_opted_in_person.select_option_title)
      end
    end

    context 'as a platform manager' do
      let(:current_user) { manager_user }

      it 'lists all current-platform people but excludes other-platform members' do
        get better_together.new_conversation_path(locale: I18n.default_locale)

        expect(response).to have_http_status(:ok)
        expect(participant_option_labels).to include(
          manager_user.person.select_option_title,
          regular_user.person.select_option_title,
          opted_in_person.select_option_title,
          non_opted_person.select_option_title,
          host_only_opted_in_person.select_option_title
        )
        expect(participant_option_labels).not_to include(other_platform_opted_in_person.select_option_title)
      end
    end
  end

  describe 'POST /conversations' do
    before { login(regular_user.email, 'SecureTest123!@#') }

    it 'creates conversations only with permitted current-platform participants' do
      post better_together.conversations_path(locale: I18n.default_locale), params: {
        conversation: {
          title: 'Hello',
          participant_ids: [opted_in_person.id, non_opted_person.id, other_platform_opted_in_person.id],
          messages_attributes: [{ content: 'Opening message' }]
        }
      }

      expect(response).to have_http_status(:found)

      conversation = BetterTogether::Conversation.order(created_at: :desc).first
      expect(conversation.creator).to eq(regular_user.person)
      expect(conversation.participants.pluck(:id)).to contain_exactly(regular_user.person.id, opted_in_person.id)
    end

    it 'shows an error when only non-permitted participants are submitted' do
      before_count = BetterTogether::Conversation.count

      post better_together.conversations_path(locale: I18n.default_locale), params: {
        conversation: {
          title: 'Hello',
          participant_ids: [non_opted_person.id, other_platform_opted_in_person.id],
          messages_attributes: [{ content: 'Opening message' }]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(BetterTogether::Conversation.count).to eq(before_count)
      expect(response.body).to include(I18n.t('better_together.conversations.errors.no_permitted_participants'))
    end
  end

  describe 'GET /conversations/:id' do
    before { login(regular_user.email, 'SecureTest123!@#') }

    it 'returns not found for a conversation the current person does not participate in' do
      conversation = create('better_together/conversation', creator: manager_user.person).tap do |c|
        c.participants << manager_user.person unless c.participants.exists?(manager_user.person.id)
      end

      get better_together.conversation_path(conversation, locale: I18n.default_locale)

      expect(response).to have_http_status(:not_found)
    end
  end

  private

  def participant_option_labels
    participant_options.map { |option| option.text.strip }.reject(&:empty?)
  end

  def participant_options
    Nokogiri::HTML(response.body).css('select[name="conversation[participant_ids][]"] option')
  end
end
