# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sending a message' do
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
      # clear_enqueued_jobs
      create_conversation([user.person])
      first('trix-editor').click.set(message)
    end

    it 'appears in the chat window' do
      find_button('Send').click
      visit conversations_path(locale: I18n.default_locale)
      expect(page).to have_content(message)
    end

    # TODO: fix race condition on event jobs
    # it 'schedules a notification job for 15 minutes later' do
    #   travel_to Time.now do
    #     expect do
    #       find_button('Send').click
    #       expect(page).to have_content(message)
    #       byebug
    #     end.to have_enqueued_job(Noticed::EventJob).once
    #     perform_enqueued_jobs
    #     expect(Noticed::DeliveryMethods::Email)
    #       .to have_been_enqueued.at(15.minutes.from_now).once
    #   end
    # end
  end
end
