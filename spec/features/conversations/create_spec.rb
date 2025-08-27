# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', :as_platform_manager do
  include BetterTogether::DeviseSessionHelpers
  let!(:user) { create(:better_together_user, :confirmed) }

  scenario 'between a platform manager and normal user' do
    select "#{user.person.name} - @#{user.person.identifier}", from: 'conversation[participant_ids][]'
    fill_in 'conversation[title]', with: Faker::Lorem.sentence(word_count: 3)
    click_button 'Create Conversation'
    expect(BetterTogether::Conversation.count).to eq(1)
  end

  context 'as a normal user' do # rubocop:todo RSpec/ContextWording
    before do
      sign_in_user(user.email, user.password)
    end

    let(:user2) { create(:better_together_user) }

    it 'cannot create conversations with private users' do
      visit new_conversation_path(locale: I18n.default_locale)
      expect('conversation[participant_ids][]').not_to have_content(user2.person.name) # rubocop:todo RSpec/ExpectActual
    end
  end
end
