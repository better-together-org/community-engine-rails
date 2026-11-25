# frozen_string_literal: true

module BetterTogether
  module Quotas
    module Types
      # Tokens spent per BetterTogether::Ai::Log::Translation call. reversible? is
      # deliberately left at the Type base class's false default: tokens are spent at
      # the provider the instant the API call happens, and nothing that happens
      # afterward to the log row (edited, soft-deleted, erased for a data-retention
      # request) un-spends them. See feedback_quota_reversibility_defaults_to_false.
      class AiTranslationTokens < BetterTogether::Quotas::Type
        KEY = 'ai_translation_tokens'

        class << self
          def key
            KEY
          end

          def unit
            :tokens
          end

          def period
            'monthly'
          end

          # Offered only when translation genuinely works for the platform: the same
          # gate TranslationsController uses (translation robot resolved for the
          # platform, and its provider has credentials, is ollama or has an adapter).
          # The key stays 'ai_translation_tokens'; the wording is generic LLM usage.
          def available_for?(platform)
            BetterTogether.translation_available?(platform:)
          end

          # An owner sees the quota only when it is granted: an effective limit above 0
          # (an active QuotaGrant, else the stored limit copied from the defaults).
          def visible_for?(quota)
            quota.effective_limit.to_i.positive?
          end

          def measure(subject)
            subject.tokens_used
          end

          # Failed/timeout provider calls that never reach TranslationBot#log_translation
          # are invisible to this ledger, a known, accepted gap, not fixed in this phase.
          def counts_toward_quota?(subject)
            subject.respond_to?(:status) ? subject.status == 'success' : true
          end
        end
      end
    end
  end
end

BetterTogether::Quotas::Type.register(
  BetterTogether::Quotas::Types::AiTranslationTokens.key,
  BetterTogether::Quotas::Types::AiTranslationTokens
)
