# frozen_string_literal: true

module BetterTogether
  class TranslationBot < ApplicationBot # rubocop:todo Style/Documentation
    DEFAULT_SYSTEM_PROMPT =
      'You are a translation assistant for CMS content. Translate text accurately for each ' \
      'type of content provided. Only return the translated text without any added explanation ' \
      'or commentary.'

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/ParameterLists
    # rubocop:todo Lint/UnusedMethodArgument
    def translate(content, target_locale:, source_locale:, attribute_name: nil, model_name: nil, initiator: nil)
      # rubocop:enable Lint/UnusedMethodArgument
      # rubocop:enable Metrics/ParameterLists
      # Step 1: Replace Trix attachments with placeholders
      attachments = {}
      processed_content = content.gsub(%r{<figure[^>]+data-trix-attachment="([^"]+)"[^>]*>.*?</figure>}) do |match|
        placeholder = "TRIX_ATTACHMENT_PLACEHOLDER_#{attachments.size}"
        attachments[placeholder] = match
        placeholder
      end

      # Step 2: Set the start time before making the request
      start_time = Time.current

      # Step 3: Translate the content without attachments
      response = ask(
        "Translate the following text from #{source_locale} to #{target_locale}: #{processed_content}",
        system_prompt: translation_system_prompt,
        temperature: 0.1,
        max_tokens: 1000
      )

      # Capture the end time after the translation completes
      end_time = Time.current

      translated_content = (response[:content].presence || 'Translation unavailable').dup

      # Step 4: Replace placeholders with original attachments
      attachments.each do |placeholder, original_attachment|
        translated_content.gsub!(placeholder, original_attachment)
      end

      # Calculate estimated cost
      prompt_tokens = normalized_token_count(response[:prompt_tokens], fallback_text: processed_content)
      completion_tokens = normalized_token_count(response[:completion_tokens], fallback_text: translated_content)
      response_model = response[:model].presence || model_name.presence || model
      estimated_cost = estimate_cost(prompt_tokens, completion_tokens, response_model)

      # Log the translation request
      if initiator
        log_translation(content, translated_content, initiator, start_time, end_time, source_locale, target_locale,
                        estimated_cost, prompt_tokens:, completion_tokens:, response_model:)
      end

      translated_content
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    private

    def default_robot_identifier
      'translation'
    end

    def translation_system_prompt
      robot&.system_prompt.presence || DEFAULT_SYSTEM_PROMPT
    end

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/ParameterLists
    def log_translation(request_content, response_content, initiator, start_time, end_time, source_locale,
                        target_locale, estimated_cost, prompt_tokens:, completion_tokens:, response_model:)
      # rubocop:enable Metrics/ParameterLists
      BetterTogether::Ai::Log::TranslationLoggerJob.perform_later(
        request_content:,
        response_content:,
        prompt_tokens:,
        completion_tokens:,
        start_time:,
        end_time:,
        model: response_model,
        initiator:,
        source_locale:, # Pass source locale
        target_locale:, # Pass target locale
        estimated_cost: # Pass estimated cost
      )
    end
    # rubocop:enable Metrics/MethodLength

    def estimate_cost(prompt_tokens, completion_tokens, model)
      rates = {
        'gpt-4o-mini-2024-07-18' => { prompt: 0.03 / 1000, completion: 0.06 / 1000 },
        'gpt-3.5-turbo' => { prompt: 0.02 / 1000, completion: 0.02 / 1000 },
        'text-embedding-3-small' => { prompt: 0.02 / 1000, completion: 0 }
      }
      model_rates = rates[model] || { prompt: 0, completion: 0 }
      ((prompt_tokens * model_rates[:prompt]) + (completion_tokens * model_rates[:completion])).round(5)
    end

    def normalized_token_count(value, fallback_text:)
      return value.to_i if value.present?

      approximate_token_count(fallback_text)
    end

    def approximate_token_count(content)
      (content.to_s.bytesize / 4.0).ceil
    end
  end
end
