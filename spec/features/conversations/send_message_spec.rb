# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sending a message', :as_platform_manager do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers
  include BetterTogether::ConversationHelpers

  before do
    login_as_platform_manager
  end

  let(:user) { create(:better_together_user, :confirmed) }
  let(:message) { Faker::Lorem.sentence }

  context 'when message is sent', :js do
    before do
      # clear_enqueued_jobs
      create_conversation([user.person])
      # Ensure the trix editor is present and set its content through the editor API to avoid Selenium visibility issues
      expect(page).to have_selector('trix-editor', wait: 5) # rubocop:todo RSpec/ExpectInHook
      page.execute_script(<<~JS)
        (function(){
          var editor = document.querySelector('trix-editor');
          if (!editor) return;
          var inputId = editor.getAttribute('input');
          var input = document.getElementById(inputId);
          if (input) { input.value = #{message.to_json}; }
          if (editor.editor && typeof editor.editor.loadHTML === 'function') {
            editor.editor.loadHTML(#{message.to_json});
          } else if (editor.setInput) {
            try { editor.setInput(#{message.to_json}); } catch(e) { /* noop */ }
          } else {
            editor.innerHTML = #{message.to_json};
          }
          editor.dispatchEvent(new Event('input', { bubbles: true }));
        })();
      JS
    end

    it 'appears in the chat window' do
      find_button('Send').click
      
      # Wait for the message to appear in the current conversation via Turbo Stream
      expect(page).to have_content(message, wait: 10)
      
      # Now visit the conversations index and verify the message is there too
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
