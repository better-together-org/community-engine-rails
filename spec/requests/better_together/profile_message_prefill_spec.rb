# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile message prefill' do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }
  let!(:other_platform) { create(:better_together_platform) }
  let!(:user) { create(:user, :confirmed, email: 'user@example.test', password: 'SecureTest123!@#') }
  let!(:other_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Target Person')
  end
  let!(:other_platform_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Remote Target')
  end

  before do
    create(:better_together_person_platform_membership, member: user.person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: other_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: other_platform_person, joinable: other_platform)
    login(user.email, 'SecureTest123!@#')
  end

  it 'preselects a permitted current-platform person from the profile message link' do
    get better_together.new_conversation_path(locale: I18n.default_locale,
                                              conversation: { participant_ids: [other_person.id] })

    expect(response).to have_http_status(:ok)
    expect(selected_participant_values).to include(other_person.id)
  end

  it 'does not render a preselected option for a person outside the current platform' do
    get better_together.new_conversation_path(locale: I18n.default_locale,
                                              conversation: { participant_ids: [other_platform_person.id] })

    expect(response).to have_http_status(:ok)
    expect(participant_values).not_to include(other_platform_person.id)
    expect(selected_participant_values).not_to include(other_platform_person.id)
  end

  private

  def participant_values
    participant_options.map { |option| option['value'] }
  end

  def selected_participant_values
    participant_options.select { |option| option['selected'].present? }.map { |option| option['value'] }
  end

  def participant_options
    Nokogiri::HTML(response.body).css('select[name="conversation[participant_ids][]"] option')
  end
end
