# frozen_string_literal: true

module BetterTogether
  module ConversationHelpers
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    def create_conversation(*participants)
      visit new_conversation_path(locale: I18n.default_locale)
      participants.each do |participant|
        select "#{participant.person.name} - @#{participant.person.identifier}", from: 'conversation[participant_ids][]'
      end
      click_button 'Create Conversation'
    end
  end
end
