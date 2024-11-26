# frozen_string_literal: true

module BetterTogether
  class TranslationsController < ApplicationController
    def translate
      content = params[:content]
      source_locale = params[:source_locale]
      target_locale = params[:target_locale]
      initiator = helpers.current_person

      # Initialize the TranslationBot
      translation_bot = BetterTogether::TranslationBot.new

      # Perform the translation using TranslationBot
      translated_content = translation_bot.translate(content, target_locale:,
                                                              source_locale:, initiator:)

      # Return the translated content as JSON
      render json: { translation: translated_content }
    rescue StandardError => e
      render json: { error: "Translation failed: #{e.message}" }, status: :unprocessable_entity
    end
  end
end
