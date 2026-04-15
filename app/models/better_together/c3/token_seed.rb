# frozen_string_literal: true

module BetterTogether
  module C3
    # TokenSeed is a portable C3 contribution envelope for cross-platform settlement.
    # It is an STI subclass of Seed (lane: 'c3_transfer').
    #
    # Wire format sent from Platform A to Platform B:
    #   POST /federation/c3/token_seeds
    #   { "c3_token_seed": {
    #       "token_id":          <uuid from source platform>,
    #       "earner_did":        "did:key:z6Mk...",
    #       "payer_did":         "did:key:z6Mk...",    # optional — present when settling a lock
    #       "contribution_type": "compute_gpu",
    #       "c3_millitokens":    18750,
    #       "source_ref":        "settlement:abc123",
    #       "source_system":     "borgberry" | "ce_joatu",
    #       "emitted_at":        "2026-04-15T00:00:00Z"
    #   } }
    #
    # On receipt, `apply_to_recipient_balance!` credits the earner's local balance,
    # settling from the payer's locked balance if `payer_did` is present and found locally.
    class TokenSeed < BetterTogether::Seed # rubocop:todo Metrics/ClassLength
      LANE = 'c3_transfer'
      VERSION = '1.0'

      # Build a TokenSeed envelope from a locally-minted C3::Token.
      # Used by borgberry `seed dispatch` and the federation settlement path.
      def self.from_token(token, source_platform:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        identifier = "c3_token:#{token.id}"
        description = "C3 #{token.contribution_type_name} #{token.c3_amount} C3 (#{token.source_ref})"

        new(
          type: name,
          identifier: identifier,
          version: VERSION,
          created_by: source_platform.identifier,
          seeded_at: token.emitted_at || Time.current,
          description: description,
          origin: {
            lane: LANE,
            platforms: [source_platform.identifier],
            source_ref: token.source_ref,
            source_system: token.source_system
          },
          payload: {
            token_id: token.id,
            earner_did: token.earner.try(:borgberry_did),
            contribution_type: token.contribution_type,
            c3_millitokens: token.c3_millitokens,
            status: token.status,
            source_ref: token.source_ref,
            source_system: token.source_system,
            emitted_at: token.emitted_at&.iso8601
          }
        )
      end

      # Build a TokenSeed from an inbound wire payload hash (controller params).
      # Returns an unsaved record — call save! or import_or_update! to persist.
      def self.from_wire_params(params, source_platform:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        token_id = params[:token_id].to_s
        identifier = "c3_token:#{token_id}"

        new(
          type: name,
          identifier: identifier,
          version: VERSION,
          created_by: source_platform.identifier,
          seeded_at: safe_parse_time(params[:emitted_at]),
          description: "Federated C3 #{params[:contribution_type]} " \
                       "#{(params[:c3_millitokens].to_i / BetterTogether::C3::Token::MILLITOKEN_SCALE.to_f).round(4)} C3",
          origin: {
            lane: LANE,
            platforms: [source_platform.identifier],
            source_ref: params[:source_ref],
            source_system: params[:source_system] || 'federation'
          },
          payload: params.slice(
            :token_id, :earner_did, :payer_did, :lock_ref, :contribution_type,
            :c3_millitokens, :source_ref, :source_system, :emitted_at
          ).to_h
        )
      end

      # Apply this seed's payload to the recipient's C3 balance.
      #
      # If payer_did is present, the settlement MUST also carry a lock_ref that
      # matches a pending C3::BalanceLock on the payer's local balance.  If the
      # lock cannot be verified the seed is saved (audit trail) but not applied —
      # returns false so the caller can respond 202 Accepted.
      #
      # If payer_did is absent (simple inbound transfer) the earner's balance is
      # credited directly without a lock check.
      #
      # Returns true if value was transferred, false if deferred/unverifiable.
      def apply_to_recipient_balance!(origin_platform: nil) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Naming/PredicateMethod
        data = payload_data.with_indifferent_access
        earner_did  = data[:earner_did].to_s
        payer_did   = data[:payer_did].to_s
        lock_ref    = data[:lock_ref].to_s
        millitokens = data[:c3_millitokens].to_i

        return false if earner_did.blank? || millitokens <= 0

        recipient = BetterTogether::Person.find_by(borgberry_did: earner_did)
        unless recipient
          Rails.logger.warn("[C3::TokenSeed] earner DID not found locally: #{earner_did.first(16)}…")
          return false
        end

        # Federated balances are tracked per origin platform for cross-platform accounting.
        recipient_balance = BetterTogether::C3::Balance.find_or_create_by!(
          holder: recipient, community: nil, origin_platform: origin_platform
        )

        if payer_did.present?
          return apply_locked_settlement!(data, payer_did, lock_ref, recipient_balance, millitokens, origin_platform)
        end

        # Simple inbound transfer — no payer lock required.
        apply_direct_credit!(data, recipient, recipient_balance, millitokens, origin_platform)
        true
      end

      private

      # Settle from payer's locked balance to recipient; requires a matching pending lock.
      def apply_locked_settlement!(data, payer_did, lock_ref, recipient_balance, millitokens, origin_platform) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/ParameterLists, Metrics/PerceivedComplexity, Naming/PredicateMethod
        payer = BetterTogether::Person.find_by(borgberry_did: payer_did)
        unless payer
          Rails.logger.warn("[C3::TokenSeed] payer_did not found locally: #{payer_did.first(16)}…")
          return false
        end

        payer_balance = BetterTogether::C3::Balance.find_by(holder: payer, community: nil)
        unless payer_balance
          Rails.logger.warn("[C3::TokenSeed] no local balance found for payer #{payer.id}")
          return false
        end

        if lock_ref.blank?
          Rails.logger.warn('[C3::TokenSeed] payer_did present but lock_ref missing — refusing settlement')
          return false
        end

        # Verify the lock belongs to this payer and is still pending.
        lock = payer_balance.balance_locks.pending.find_by(lock_ref: lock_ref)
        unless lock
          Rails.logger.warn("[C3::TokenSeed] lock_ref #{lock_ref.first(8)}… not found or not pending for payer #{payer.id}")
          return false
        end

        c3_amount = millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE

        transaction do
          payer_balance.settle_to!(recipient_balance, c3_amount, lock_ref: lock_ref)

          BetterTogether::C3::Token.create!(
            earner: recipient_balance.holder,
            contribution_type: data[:contribution_type] || :volunteer,
            contribution_type_name: data[:contribution_type] || 'federated_transfer',
            c3_millitokens: millitokens,
            source_ref: data[:source_ref] || "token_seed:#{id}",
            source_system: data[:source_system] || 'federation',
            status: 'confirmed',
            federated: true,
            origin_platform: origin_platform,
            emitted_at: self.class.send(:safe_parse_time, data[:emitted_at]) || Time.current,
            confirmed_at: Time.current
          )
        end

        true
      end

      # Credit recipient directly (no payer lock — simple inbound transfer).
      def apply_direct_credit!(data, recipient, recipient_balance, millitokens, origin_platform) # rubocop:todo Metrics/MethodLength
        c3_amount = millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE

        transaction do
          recipient_balance.credit!(c3_amount)

          BetterTogether::C3::Token.create!(
            earner: recipient,
            contribution_type: data[:contribution_type] || :volunteer,
            contribution_type_name: data[:contribution_type] || 'federated_transfer',
            c3_millitokens: millitokens,
            source_ref: data[:source_ref] || "token_seed:#{id}",
            source_system: data[:source_system] || 'federation',
            status: 'confirmed',
            federated: true,
            origin_platform: origin_platform,
            emitted_at: self.class.send(:safe_parse_time, data[:emitted_at]) || Time.current,
            confirmed_at: Time.current
          )
        end
      end

      def self.safe_parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        Time.current
      end
      private_class_method :safe_parse_time
    end
  end
end
