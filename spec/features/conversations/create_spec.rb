# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let!(:user) { create(:better_together_user, :confirmed) }

  scenario 'between a platform manager and normal user' do
    visit new_conversation_path(locale: I18n.default_locale)
    select "#{user.person.name} - @#{user.person.identifier}", from: 'conversation[participant_ids][]'
    fill_in 'conversation[title]', with: Faker::Lorem.sentence(word_count: 3)
    click_button 'Create Conversation'
    expect(BetterTogether::Conversation.count).to eq(1)
  end

  context 'as a normal user' do
    before do
      sign_out_current_user
      sign_in_user(user.email, user.password)
    end
    let(:user2) do
      create(:better_together_user)
    end

    it 'cannot create conversations with private users' do
      visit new_conversation_path(locale: I18n.default_locale)
      expect('conversation[participant_ids][]').not_to have_content(user2.person.name)
    end
  end
end
