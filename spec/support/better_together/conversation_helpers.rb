# frozen_string_literal: true

module BetterTogether
  module ConversationHelpers
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    # participants - array of Person-like objects (respond_to? :slug)
    # options - optional hash: :title, :first_message
    def create_conversation(participants, options = {}) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      visit new_conversation_path(locale: I18n.default_locale)

      # Wait for the participants select control to render (slim-select wrapper)
      select_wrapper = find('.ss-main', match: :first)
      select_wrapper.click

      participants.each do |participant|
        # pick option by slug (keeps existing behaviour) but wait for it to appear
        option = find('.ss-content > .ss-list > .ss-option', text: Regexp.new(Regexp.escape(participant.slug.to_s)))
        option.click
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
