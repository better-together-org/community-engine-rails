# frozen_string_literal: true

module BetterTogether
  module Embeddings
    # Default embedding adapter backed by RubyLLM.
    class DefaultAdapter
      def call(text, **options)
        response = RubyLLM.embed(text, **embedding_options(options))

        {
          vectors: response.vectors,
          model: response.model,
          prompt_tokens: response.input_tokens.to_i,
          provider: provider&.to_s,
          raw_response: response
        }
      end

      private

      def embedding_options(options)
        embedding_options = {}
        embedding_options[:model] = options[:model] if options[:model].present?
        embedding_options[:provider] = options[:provider].to_sym if options[:provider].present?
        embedding_options[:dimensions] = options[:dimensions] if options[:dimensions].present?
        embedding_options[:assume_model_exists] = true if options[:assume_model_exists]
        embedding_options
      end
    end
  end
end
