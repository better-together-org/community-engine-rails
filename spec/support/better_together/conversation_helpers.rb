# frozen_string_literal: true

module BetterTogether
  module ConversationHelpers
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    # participants - array of Person-like objects (respond_to? :slug)
    # options - optional hash: :title, :first_message
    def create_conversation(participants, options = {}) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Always navigate to the conversation form to ensure clean state
      visit new_conversation_path(locale: I18n.default_locale)

      # Wait for page to fully load - check for conversation form container
      expect(page).to have_css('#new_conversation_form', wait: 10)

      # Ensure authentication is established - must NOT see login form
      # Give it up to 10 seconds for session to propagate
      expect(page).not_to have_css('input[name="user[email]"]', wait: 10)

      # Wait for the actual form element (form_with generates model-based IDs)
      # For a new conversation it will be: new_better_together_conversation
      expect(page).to have_css('form', wait: 10)

      # Wait for underlying select element (following timezone selector pattern)
      # The select is hidden but present in DOM with name="conversation[participant_ids][]"
      expect(page).to have_css('select[name="conversation[participant_ids][]"]', visible: :all, wait: 10)

      # Then wait for SlimSelect Stimulus controller to initialize and create its wrapper
      expect(page).to have_css('.ss-main', wait: 5)

      participants.each_with_index do |participant, index|
        # Open SlimSelect dropdown
        find('.ss-main', match: :first).click

        # Prefer matching by name to align with select_option_title output
        option_matcher = Regexp.new(Regexp.escape(participant.name.to_s))
        option = find('.ss-content .ss-list .ss-option', text: option_matcher, wait: 10)
        option.click

        # SlimSelect closes after selection; reopen for the next participant
        find('.ss-main', match: :first).click if index < participants.length - 1
      end

      # Give the widget a moment to update (widget reflects selections visually)
      # (Do not assert on the hidden <select> element; keep the original widget-driven selection behavior)

      # Fill title
      title = options.fetch(:title) { Faker::Lorem.sentence(word_count: 3) }
      fill_in 'conversation[title]', with: title

      # Fill first message if present in the form. Support plain textarea or Trix editor.
      first_message = options.fetch(:first_message, Faker::Lorem.sentence(word_count: 8))
      if page.has_field?('conversation[first_message]')
        fill_in 'conversation[first_message]', with: first_message
      elsif page.has_selector?('trix-editor')
        # Use the same robust Trix activation logic used in feature specs
        page.execute_script(<<~JS)
          (function(){
            var editor = document.querySelector('trix-editor');
            if (!editor) return;
            var inputId = editor.getAttribute('input');
            var input = document.getElementById(inputId);
            if (input) { input.value = #{first_message.to_json}; }
            if (editor.editor && typeof editor.editor.loadHTML === 'function') {
              editor.editor.loadHTML(#{first_message.to_json});
            } else if (editor.setInput) {
              try { editor.setInput(#{first_message.to_json}); } catch(e) { /* noop */ }
            } else {
              editor.innerHTML = #{first_message.to_json};
            }
            editor.dispatchEvent(new Event('input', { bubbles: true }));
          })();
        JS
        expect(page).to have_selector('trix-editor', text: first_message, wait: 2)
      end

      # Submit using the button label present in the UI (keep original label to avoid brittle tests)
      click_button 'Create Conversation'
    end
  end
end
