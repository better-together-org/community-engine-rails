# app/jobs/better_together/ai/log/translation_logger_job.rb

module BetterTogether
  module Ai
    module Log
      class TranslationLoggerJob < ApplicationJob
        queue_as :default

        def perform(
          request_content:, response_content:, prompt_tokens:, completion_tokens:,
          start_time:, end_time:, model:, initiator:, source_locale:, target_locale:, estimated_cost:
        )
          tokens_used = prompt_tokens + completion_tokens

          BetterTogether::Ai::Log::Translation.create!(
            request: request_content,
            response: response_content,
            start_time: start_time,
            end_time: end_time,
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens,
            tokens_used: tokens_used,
            model: model,
            estimated_cost: estimated_cost, # Receive estimated cost from the bot
            status: response_content.present? ? 'success' : 'failure',
            initiator: initiator,
            source_locale: source_locale, # Added source locale
            target_locale: target_locale # Added target locale
          )
        end
      end
    end
  end
end
