# frozen_string_literal: true

module BetterTogether
  class TranslationBot < ApplicationBot # rubocop:todo Style/Documentation
    DEFAULT_SYSTEM_PROMPT =
      'You are a translation assistant for CMS content. Translate text accurately for each ' \
      'type of content provided. Only return the translated text without any added explanation ' \
      'or commentary.'

    # Idempotency key for one translation's ai_translation_tokens charge, shared by
    # #settle_translation_tokens_quota and Quotas::Backfill.
    def self.translation_charge_key(log_id)
      "ai_translation_tokens:settle:log:#{log_id}"
    end

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

      # Tokens are spent at the provider whether or not anyone initiated the call, so
      # metering happens for every translation; only the log row needs an initiator.
      # log_id is generated here so the usage row and the async log row share one
      # identity (see #settle_translation_tokens_quota).
      log_id = SecureRandom.uuid
      settle_translation_tokens_quota(initiator, log_id, prompt_tokens, completion_tokens)

      # Log the translation request
      if initiator
        log_translation(content, translated_content, initiator, start_time, end_time, source_locale, target_locale,
                        estimated_cost, prompt_tokens:, completion_tokens:, response_model:, log_id:)
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
                        target_locale, estimated_cost, prompt_tokens:, completion_tokens:, response_model:,
                        log_id: nil)
      # rubocop:enable Metrics/ParameterLists
      BetterTogether::Ai::Log::TranslationLoggerJob.perform_later(
        log_id:,
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
        estimated_cost:, # Pass estimated cost
        # Captured here (request/robot context) since the job itself runs async
        # with no Current.platform to fall back on. robot&.platform_id first —
        # the bot was resolved for a specific platform via Robot.resolve, same
        # signal #robot_metadata already uses — falling back to Current.platform
        # only if the resolved robot is a platform-agnostic global fallback.
        platform_id: robot&.platform_id || ::Current.platform&.id
      )
    end
    # rubocop:enable Metrics/MethodLength

    # Settle-only, no pre-call reserve!: token counts are only known after the
    # provider call returns (see #translate above). subject: nil because the
    # Ai::Log::Translation row doesn't exist yet, created async with id log_id. The
    # idempotency key is built from that id, the same key Quotas::Backfill uses for
    # the log row, so the backfill never charges these tokens a second time, and
    # every call gets its own key however many run at once. With no initiator the
    # owner resolves to the Platform. Errors are caught non-fatally, a
    # quota-tracking bug must never break translation.
    def settle_translation_tokens_quota(initiator, log_id, prompt_tokens, completion_tokens)
      BetterTogether::Quotas.settle!(
        type: 'ai_translation_tokens',
        owner: BetterTogether::Quotas::OwnerResolver.resolve(initiator),
        amount: prompt_tokens + completion_tokens,
        idempotency_key: self.class.translation_charge_key(log_id),
        actor: initiator
      )
    rescue StandardError => e
      Rails.logger.warn("[Quotas] settle! failed non-fatally for ai_translation_tokens: #{e.class}: #{e.message}")
    end

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
