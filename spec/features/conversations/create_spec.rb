# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let!(:user) { create(:better_together_user) }

  scenario 'between a platform manager and normal user' do
    visit new_conversation_path(locale: I18n.default_locale)
    select "#{user.person.name} - @#{user.person.identifier}", from: 'conversation[participant_ids][]'
    fill_in 'conversation[title]', with: Faker::Lorem.sentence(word_count: 3)
    click_button 'Create Conversation'
    expect(BetterTogether::Conversation.count).to eq(1)
  end
end
