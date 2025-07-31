# frozen_string_literal: true

module BetterTogether
  module ConversationHelpers
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    def create_conversation(participants)
      visit new_conversation_path(locale: I18n.default_locale)

      slim_select = find('select[name="conversation[participant_ids][]"]+div.form-select')

      slim_select.click

      participants.each do |participant|
        find('.ss-content > .ss-list > .ss-option',
             text: Regexp.new(participant.slug)).click
      end

      fill_in 'conversation[title]', with: Faker::Lorem.sentence(word_count: 3)
      click_button 'Create Conversation'
    end
  end
end
