# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sending a message', type: :feature do
  include BetterTogether::DeviseSessionHelpers
  include BetterTogether::ConversationHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let(:user) { create(:better_together_user, :confirmed) }
  let(:message) { Faker::Lorem.sentence }

  scenario 'message text appears in chat window', :js do
    create_conversation([user.person])
    first('trix-editor').click.set(message)
    find_button('Send').click
    visit conversations_path(locale: I18n.default_locale)
    expect(page).to have_content(message)
  end
end
