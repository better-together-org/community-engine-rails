# frozen_string_literal: true

module BetterTogether
  module Ai
    module Log
      class Translation < ApplicationRecord
        belongs_to :initiator, class_name: 'BetterTogether::Person', optional: true
        validates :request, :model, :status, presence: true
        validates :prompt_tokens, :completion_tokens, :tokens_used,
                  numericality: { only_integer: true, greater_than_or_equal_to: 0 }
        validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }

        # Define statuses
        enum status: { pending: 'pending', success: 'success', failure: 'failure' }

        # Calculate total tokens
        def calculate_total_tokens
          self.tokens_used = prompt_tokens + completion_tokens
        end

        # Optionally, calculate the estimated cost if necessary
        def estimated_cost
          rates = {
            'gpt-4o-mini-2024-07-18' => { prompt: 0.03 / 1000, completion: 0.06 / 1000 },
            'gpt-3.5-turbo' => { prompt: 0.02 / 1000, completion: 0.02 / 1000 }
          }

          model_rates = rates[model] || { prompt: 0, completion: 0 }
          ((prompt_tokens * model_rates[:prompt]) + (completion_tokens * model_rates[:completion])).round(5)
        end
      end
    end
  end
end
