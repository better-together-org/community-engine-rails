# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a new conversation', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let!(:user) { create(:better_together_user) }

  scenario 'with two members' do
    visit new_conversation_path(locale: I18n.default_locale)
    # byebug
    select "#{user.person.name} - @#{user.person.identifier}", from: 'conversation[participant_ids][]'
    click_button 'Create Conversation'
    expect(BetterTogether::Conversation.count).to eq(1)
  end
end
