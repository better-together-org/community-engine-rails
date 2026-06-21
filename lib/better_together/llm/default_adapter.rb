# frozen_string_literal: true

module BetterTogether
  module Llm
    # Default chat/completion adapter backed by RubyLLM.
    class DefaultAdapter
      def call(prompt:, model:, **options)
        chat = build_chat(model:, **options)
        response = chat.ask(prompt)

        serialize_response(response, model:, provider: options[:provider])
      end

      private

      def build_chat(model:, **options)
        chat = RubyLLM.chat(**chat_options(model:, provider: options[:provider],
                                           assume_model_exists: options[:assume_model_exists]))
        chat = chat.with_instructions(options[:system_prompt]) if options[:system_prompt].present?
        chat = chat.with_temperature(options[:temperature]) unless options[:temperature].nil?
        chat = chat.with_params(max_tokens: options[:max_tokens]) if options[:max_tokens].present?
        chat
      end

      def chat_options(model:, provider:, assume_model_exists:)
        options = { model: }
        options[:provider] = provider.to_sym if provider.present?
        options[:assume_model_exists] = true if assume_model_exists
        options
      end

      def serialize_response(response, model:, provider:)
        {
          content: response.content,
          model: response.model_id || model,
          prompt_tokens: response.input_tokens.to_i,
          completion_tokens: response.output_tokens.to_i,
          provider: provider&.to_s,
          raw_response: response
        }
      end
    end
  end
end
