# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sending a message', type: :feature do
  include BetterTogether::DeviseSessionHelpers
  include BetterTogether::ConversationHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let(:user) { build(:better_together_user) }
  let(:message) { Faker::Lorem.sentence }

  scenario 'message text appears in chat window', :js do
    create_conversation(user)
    first('trix-editor').click.set(message)
    click_button 'Send'
    save_and_open_page
  end
end
