# frozen_string_literal: true

module BetterTogether
  class TranslationsController < ApplicationController # rubocop:todo Style/Documentation
    def index
      # Get the locale filter from params, default to 'all'
      @locale_filter = params[:locale_filter] || 'all'
      @available_locales = I18n.available_locales.map(&:to_s)

      # Base query for translated model types
      base_query = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                   .order(:translatable_type)

      # Apply locale filter if specified
      if @locale_filter != 'all' && @available_locales.include?(@locale_filter)
        base_query = base_query.where(locale: @locale_filter)
      end

      @translated_model_types = base_query.pluck(:translatable_type).uniq

      # Calculate translation statistics per locale and model type
      @translation_stats = calculate_translation_stats if @translated_model_types.any?
    end

    private

    def calculate_translation_stats
      stats = {}

      @translated_model_types.each do |model_type|
        stats[model_type] = {}

        @available_locales.each do |locale|
          # Count total records and translated records for this model and locale
          total_records = begin
            model_type.constantize.count
          rescue StandardError
            0
          end
          translated_count = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                             .where(translatable_type: model_type, locale: locale)
                             .distinct(:translatable_id)
                             .count

          stats[model_type][locale] = {
            total: total_records,
            translated: translated_count,
            percentage: total_records > 0 ? ((translated_count.to_f / total_records) * 100).round(1) : 0
          }
        end
      end

      stats
    end

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
      render json: { error: "Translation failed: #{e.message}" }, status: :unprocessable_content
    end
  end
end
