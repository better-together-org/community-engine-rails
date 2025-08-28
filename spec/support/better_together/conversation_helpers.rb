# frozen_string_literal: true

module BetterTogether
  module ConversationHelpers
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    def create_conversation(participants)
      visit new_conversation_path(locale: I18n.default_locale)

      # Select participants directly via the underlying <select> to avoid JS timing issues
      select_box = find('select[name="conversation[participant_ids][]"]', visible: :all)
      participants.each do |participant|
        select_box.find("option[value='#{participant.id}']", visible: :all).select_option
      end

      fill_in 'conversation[title]', with: Faker::Lorem.sentence(word_count: 3)
      click_button 'Create Conversation'
    end
  end
end
