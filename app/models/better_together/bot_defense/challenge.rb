# frozen_string_literal: true

module BetterTogether
  module BotDefense
    # Issues and verifies signed challenge payloads for high-risk submissions.
    class Challenge
      ChallengePayload = Struct.new(
        :token,
        :trap_field,
        :min_submit_seconds,
        :expires_at,
        keyword_init: true
      )
      VerificationResult = Struct.new(:success?, :error, keyword_init: true)

      FORM_CONFIG = {
        registration: { min_submit_seconds: 2, expires_in: 2.hours },
        membership_request: { min_submit_seconds: 2, expires_in: 2.hours },
        membership_request_api: { min_submit_seconds: 2, expires_in: 30.minutes },
        safety_report: { min_submit_seconds: 2, expires_in: 2.hours }
      }.freeze

      class << self
        def issue(form_id:, user_agent: nil) # rubocop:todo Metrics/MethodLength
          config = config_for(form_id)
          issued_at = Time.current
          trap_field = "contact_#{SecureRandom.hex(4)}"
          payload = {
            form_id: normalize_form_id(form_id),
            issued_at: issued_at.iso8601,
            nonce: SecureRandom.hex(16),
            trap_field: trap_field,
            user_agent: user_agent.to_s.presence
          }.compact

          ChallengePayload.new(
            token: verifier.generate(payload),
            trap_field:,
            min_submit_seconds: config[:min_submit_seconds],
            expires_at: issued_at + config[:expires_in]
          )
        end

        def verify(token:, form_id:, trap_values:, user_agent: nil) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          payload = verifier.verified(token.to_s)
          return failure(:invalid_challenge) unless payload.is_a?(Hash)

          normalized_form_id = normalize_form_id(form_id)
          return failure(:invalid_challenge) if payload['form_id'] != normalized_form_id

          issued_at = Time.iso8601(payload['issued_at'].to_s)
          config = config_for(normalized_form_id)

          return failure(:expired_challenge) if issued_at + config[:expires_in] < Time.current
          return failure(:submitted_too_quickly) if Time.current < issued_at + config[:min_submit_seconds]

          trap_field = payload['trap_field'].to_s
          trap_value = trap_values.to_h.stringify_keys.fetch(trap_field, '')
          return failure(:honeypot_triggered) if trap_value.present?

          expected_user_agent = payload['user_agent'].to_s
          actual_user_agent = user_agent.to_s
          return failure(:invalid_challenge) if expected_user_agent.present? && expected_user_agent != actual_user_agent

          return failure(:replayed_challenge) unless mark_nonce_as_used(payload['nonce'], config[:expires_in])

          VerificationResult.new(success?: true, error: nil)
        rescue ArgumentError, ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
          failure(:invalid_challenge)
        end

        def supported_form_ids
          FORM_CONFIG.keys.map(&:to_s)
        end

        private

        def normalize_form_id(form_id)
          form_id.to_s
        end

        def config_for(form_id)
          FORM_CONFIG.fetch(normalize_form_id(form_id).to_sym)
        rescue KeyError
          FORM_CONFIG.fetch(:membership_request)
        end

        def verifier
          @verifier ||= ActiveSupport::MessageVerifier.new(
            Rails.application.secret_key_base,
            digest: 'SHA256',
            serializer: JSON
          )
        end

        def mark_nonce_as_used(nonce, expires_in)
          nonce_cache.write("better_together/bot_defense/nonce/#{nonce}", true, expires_in:, unless_exist: true)
        end

        def nonce_cache
          @nonce_cache ||= Rails.cache.is_a?(ActiveSupport::Cache::NullStore) ? ActiveSupport::Cache::MemoryStore.new : Rails.cache
        end

        def failure(error)
          VerificationResult.new(success?: false, error:)
        end
      end
    end
  end
end
