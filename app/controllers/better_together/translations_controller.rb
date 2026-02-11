# frozen_string_literal: true

module BetterTogether
  # Handles AI-powered translation requests via the TranslationBot (OpenAI).
  #
  # Security rationale (audit finding H4):
  #   The translate action forwards user-supplied content directly to the OpenAI API.
  #   Without input validation an authenticated user could:
  #     1. Send megabytes of text, causing unbounded API cost and slow responses.
  #     2. Pass arbitrary strings as locale parameters, which are interpolated into
  #        the AI prompt — creating a prompt-injection vector.
  #   The guards below mitigate these risks at the controller level before any
  #   content reaches the TranslationBot or the external API.
  class TranslationsController < ApplicationController
    # Maximum content size allowed for translation (50 KB).
    # This limits OpenAI token consumption and prevents abuse.
    MAX_CONTENT_SIZE = 50.kilobytes

    def translate # rubocop:todo Metrics/MethodLength
      content = params[:content]
      source_locale = params[:source_locale]
      target_locale = params[:target_locale]

      # Guard: reject blank content early to avoid a wasted API call.
      if content.blank?
        return render json: { error: 'Content cannot be blank' }, status: :unprocessable_content
      end

      # Guard: cap payload size to prevent excessive OpenAI token usage / cost.
      if content.bytesize > MAX_CONTENT_SIZE
        return render json: {
          error: 'Content is too long to translate. Please limit your text to approximately 8,000 words (~50,000 characters) and try again.'
        }, status: :unprocessable_content
      end

      # Guard: locale values are interpolated into the AI prompt, so they must
      # come from the application's configured locale list — not arbitrary user input.
      available = I18n.available_locales.map(&:to_s)
      unless available.include?(target_locale.to_s)
        return render json: { error: 'Invalid target locale' }, status: :unprocessable_content
      end

      unless available.include?(source_locale.to_s)
        return render json: { error: 'Invalid source locale' }, status: :unprocessable_content
      end

      initiator = helpers.current_person

      # Initialize the TranslationBot
      translation_bot = BetterTogether::TranslationBot.new

      # Perform the translation using TranslationBot
      translated_content = translation_bot.translate(content, target_locale:,
                                                              source_locale:, initiator:)

      # Return the translated content as JSON
      render json: { translation: translated_content }
    rescue StandardError => e
      render json: { error: "Translation failed: #{e.message}" }, status: :unprocessable_content
    end
  end
end
