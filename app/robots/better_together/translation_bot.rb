# frozen_string_literal: true

module BetterTogether
  class TranslationBot < ApplicationBot
    def translate(content, target_locale:, source_locale:, attribute_name: nil, model_name: nil, initiator: nil)
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
      response = client.chat(
        parameters: {
          model:, # Use the model from ApplicationBot
          messages: [
            { role: 'system',
              content: 'You are a translation assistant for CMS content. Translate text accurately for each type of content provided. Only return the translated text without any added explanation or commentary.' },
            { role: 'user', content: "Translate the following text to #{target_locale}: #{processed_content}" }
          ],
          temperature: 0.1,
          max_tokens: 1000
        }
      )

      # Capture the end time after the translation completes
      end_time = Time.current

      translated_content = response.dig('choices', 0, 'message', 'content') || 'Translation unavailable'

      # Step 4: Replace placeholders with original attachments
      attachments.each do |placeholder, original_attachment|
        translated_content.gsub!(placeholder, original_attachment)
      end

      # Calculate estimated cost
      estimated_cost = estimate_cost(count_tokens(processed_content), count_tokens(translated_content), model)

      # Log the translation request
      if initiator
        log_translation(content, translated_content, initiator, start_time, end_time, source_locale, target_locale,
                        estimated_cost)
      end

      translated_content
    end

    private

    def log_translation(request_content, response_content, initiator, start_time, end_time, source_locale,
                        target_locale, estimated_cost)
      BetterTogether::Ai::Log::TranslationLoggerJob.perform_later(
        request_content:,
        response_content:,
        prompt_tokens: count_tokens(request_content),
        completion_tokens: count_tokens(response_content),
        start_time:,
        end_time:,
        model:, # Use the model from ApplicationBot
        initiator:,
        source_locale:, # Pass source locale
        target_locale:, # Pass target locale
        estimated_cost: # Pass estimated cost
      )
    end

    def estimate_cost(prompt_tokens, completion_tokens, model)
      rates = {
        'gpt-4o-mini-2024-07-18' => { prompt: 0.03 / 1000, completion: 0.06 / 1000 },
        'gpt-3.5-turbo' => { prompt: 0.02 / 1000, completion: 0.02 / 1000 }
      }
      model_rates = rates[model] || { prompt: 0, completion: 0 }
      ((prompt_tokens * model_rates[:prompt]) + (completion_tokens * model_rates[:completion])).round(5)
    end

    def count_tokens(content)
      # Use OpenAI's method to estimate token count
      OpenAI.rough_token_count(content) # Assuming this method is available
    end
  end
end
