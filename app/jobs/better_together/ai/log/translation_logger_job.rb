# frozen_string_literal: true

# app/jobs/better_together/ai/log/translation_logger_job.rb

module BetterTogether
  module Ai
    module Log
      class TranslationLoggerJob < ApplicationJob # rubocop:todo Style/Documentation
        queue_as :default

        # rubocop:todo Metrics/ParameterLists
        def perform( # rubocop:todo Metrics/MethodLength, Metrics/ParameterLists
          request_content:, response_content:, prompt_tokens:, completion_tokens:,
          start_time:, end_time:, model:, initiator:, source_locale:, target_locale:, estimated_cost:
        )
          # rubocop:enable Metrics/ParameterLists
          tokens_used = prompt_tokens + completion_tokens

          BetterTogether::Ai::Log::Translation.create!(
            request: request_content,
            response: response_content,
            start_time:,
            end_time:,
            prompt_tokens:,
            completion_tokens:,
            tokens_used:,
            model:,
            estimated_cost:, # Receive estimated cost from the bot
            status: response_content.present? ? 'success' : 'failure',
            initiator:,
            source_locale:, # Added source locale
            target_locale: # Added target locale
          )
        end
      end
    end
  end
end
