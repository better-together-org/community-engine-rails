# frozen_string_literal: true

module BetterTogether
  class TranslationsController < ApplicationController # rubocop:todo Style/Documentation
    # Maximum content size allowed for translation (50 KB)
    MAX_CONTENT_SIZE = 50.kilobytes

    def translate
      content = params[:content]
      source_locale = params[:source_locale]
      target_locale = params[:target_locale]

      # Validate content presence and size
      if content.blank?
        return render json: { error: 'Content cannot be blank' }, status: :unprocessable_content
      end

      if content.bytesize > MAX_CONTENT_SIZE
        return render json: { error: 'Content exceeds maximum allowed size' }, status: :unprocessable_content
      end

      # Validate locale parameters against available locales
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
