# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sending a message', type: :feature do # rubocop:todo Metrics/BlockLength
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers
  include BetterTogether::DeviseSessionHelpers
  include BetterTogether::ConversationHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let(:user) { create(:better_together_user, :confirmed) }
  let(:message) { Faker::Lorem.sentence }

  context 'when message is sent', :js do
    before do
      create_conversation([user.person])
      first('trix-editor').click.set(message)
    end

    it 'appears in the chat window' do
      find_button('Send').click
      visit conversations_path(locale: I18n.default_locale)
      expect(page).to have_content(message)
    end

    it 'schedules a notification job for 15 minutes later' do
      expect do
        find_button('Send').click
        expect(page).to have_content(message, wait: 5)
      end.to have_enqueued_job(Noticed::EventJob).once
    end
  end
end
