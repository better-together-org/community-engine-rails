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

      # Returned by apply_to_recipient_balance! so callers can distinguish
      # successful transfer (201) from deferred/unverifiable (202) without
      # inspecting a bare true/false.
      Result = Struct.new(:applied, :reason)

      # Encrypt the wire payload at rest — it contains earner/payer DIDs and
      # settlement amounts that should not be readable in a database extract.
      # Non-deterministic: payload is write-once and never queried by content.
      encrypts :payload

      # Build a TokenSeed envelope from a locally-minted C3::Token.
      # Used by borgberry `seed dispatch` and the federation settlement path.
      #
      # source_ref is replaced with a one-way SHA-256 hash before it leaves
      # the platform.  This prevents peer platforms from learning internal
      # agreement or settlement UUIDs from the wire payload.  The hash binds
      # the ref to the originating platform identifier so it is unique across
      # the federation but not reversible.  Stored locally as source_ref_hash.
      def self.from_token(token, source_platform:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        identifier = "c3_token:#{token.id}"
        description = "C3 #{token.contribution_type_name} #{token.c3_amount} C3 (#{token.source_ref})"
        source_ref_hash = hash_source_ref(token.source_ref, source_platform.identifier)

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
            source_ref_hash: source_ref_hash,
            source_system: token.source_system
          },
          payload: {
            token_id: token.id,
            earner_did: token.earner.try(:borgberry_did),
            contribution_type: token.contribution_type,
            c3_millitokens: token.c3_millitokens,
            status: token.status,
            source_ref_hash: source_ref_hash,
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
            :c3_millitokens, :source_ref, :source_ref_hash, :source_system, :emitted_at
          ).to_h
        )
      end

      # Apply this seed's payload to the recipient's C3 balance.
      #
      # Returns a Result struct with:
      #   applied: true  — value transferred; caller should respond 201 Created
      #   applied: false — deferred or unverifiable; caller should respond 202 Accepted
      #   reason:        — symbol explaining why (nil on success)
      #
      # Reasons for deferred response:
      #   :earner_did_not_found_locally — DID not enrolled on this platform
      #   :no_active_connection          — no active C3-exchange connection found
      #   :payer_not_found_locally       — payer_did present but not enrolled here
      #   :payer_balance_not_found       — payer has no local balance
      #   :lock_ref_required             — payer_did present but lock_ref absent
      #   :lock_ref_not_found            — lock_ref does not match a pending lock
      def apply_to_recipient_balance!(origin_platform: nil) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Naming/PredicateMethod
        data = payload_data.with_indifferent_access
        earner_did  = data[:earner_did].to_s
        payer_did   = data[:payer_did].to_s
        lock_ref    = data[:lock_ref].to_s
        millitokens = data[:c3_millitokens].to_i

        return Result.new(false, :invalid_payload) if earner_did.blank? || millitokens <= 0
        return Result.new(true, :already_applied) if already_applied?(data)

        recipient = BetterTogether::Person.find_by(borgberry_did: earner_did)
        unless recipient
          Rails.logger.warn("[C3::TokenSeed] earner DID not found locally: #{earner_did.first(16)}…")
          return Result.new(false, :earner_did_not_found_locally)
        end

        rate, effective_millitokens = resolve_exchange_rate(origin_platform, millitokens)
        if rate.nil?
          Rails.logger.warn('[C3::TokenSeed] no active C3 connection — deferring settlement')
          return Result.new(false, :no_active_connection)
        end

        # Federated balances are tracked per origin platform for cross-platform accounting.
        recipient_balance = BetterTogether::C3::Balance.find_or_create_by!(
          holder: recipient, community: nil, origin_platform: origin_platform
        )

        if payer_did.present?
          return apply_locked_settlement!(data, payer_did, lock_ref, recipient_balance,
                                          effective_millitokens, origin_platform, rate: rate)
        end

        # Simple inbound transfer — no payer lock required.
        apply_direct_credit!(data, recipient, recipient_balance, effective_millitokens, origin_platform, rate: rate)
        Result.new(true, nil)
      end

      private

      # Resolve the bilateral C3 exchange rate from the PlatformConnection between
      # origin_platform and the current platform.  Returns [rate, effective_millitokens].
      # Returns [nil, nil] if no active C3-enabled connection is found.
      # When origin_platform is nil (local), rate is 1.0 and millitokens are unchanged.
      def resolve_exchange_rate(origin_platform, millitokens)
        if origin_platform.nil?
          return [1.0, millitokens]
        end

        connection = BetterTogether::PlatformConnection.active.find_by(
          source_platform: origin_platform, target_platform: Current.platform
        )
        connection ||= BetterTogether::PlatformConnection.active.find_by(
          source_platform: Current.platform, target_platform: origin_platform
        )

        return [nil, nil] unless connection&.allows_c3_exchange?

        rate = connection.c3_exchange_rate_value
        effective = (millitokens * rate).round
        [rate, effective]
      end

      # Settle from payer's locked balance to recipient; requires a matching pending lock.
      def apply_locked_settlement!(data, payer_did, lock_ref, recipient_balance, millitokens, origin_platform, rate: 1.0) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/ParameterLists, Metrics/PerceivedComplexity, Naming/PredicateMethod
        payer = BetterTogether::Person.find_by(borgberry_did: payer_did)
        unless payer
          Rails.logger.warn("[C3::TokenSeed] payer_did not found locally: #{payer_did.first(16)}…")
          return Result.new(false, :payer_not_found_locally)
        end

        payer_balance = BetterTogether::C3::Balance.find_by(holder: payer, community: nil)
        unless payer_balance
          Rails.logger.warn("[C3::TokenSeed] no local balance found for payer #{payer.id}")
          return Result.new(false, :payer_balance_not_found)
        end

        if lock_ref.blank?
          Rails.logger.warn('[C3::TokenSeed] payer_did present but lock_ref missing — refusing settlement')
          return Result.new(false, :lock_ref_required)
        end

        # Verify the lock belongs to this payer and is still pending.
        lock = payer_balance.balance_locks.pending.find_by(lock_ref: lock_ref)
        unless lock
          Rails.logger.warn("[C3::TokenSeed] lock_ref #{lock_ref.first(8)}… not found or not pending for payer #{payer.id}")
          return Result.new(false, :lock_ref_not_found)
        end

        c3_amount = millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE

        transaction do
          payer_balance.settle_to!(recipient_balance, c3_amount, lock_ref: lock_ref)

          BetterTogether::C3::Token.create!(
            earner: recipient_balance.holder,
            contribution_type: data[:contribution_type] || :volunteer,
            contribution_type_name: data[:contribution_type] || 'federated_transfer',
            c3_millitokens: millitokens,
            source_ref: data[:source_ref_hash] || data[:source_ref] || "token_seed:#{id}",
            source_system: data[:source_system] || 'federation',
            status: 'confirmed',
            federated: true,
            origin_platform: origin_platform,
            metadata: { exchange_rate: rate, original_millitokens: data[:c3_millitokens].to_i },
            emitted_at: self.class.send(:safe_parse_time, data[:emitted_at]) || Time.current,
            confirmed_at: Time.current
          )
        end

        Result.new(true, nil)
      end

      # Credit recipient directly (no payer lock — simple inbound transfer).
      def apply_direct_credit!(data, recipient, recipient_balance, millitokens, origin_platform, rate: 1.0) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
        c3_amount = millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE

        transaction do
          recipient_balance.credit!(c3_amount)

          BetterTogether::C3::Token.create!(
            earner: recipient,
            contribution_type: data[:contribution_type] || :volunteer,
            contribution_type_name: data[:contribution_type] || 'federated_transfer',
            c3_millitokens: millitokens,
            source_ref: data[:source_ref_hash] || data[:source_ref] || "token_seed:#{id}",
            source_system: data[:source_system] || 'federation',
            status: 'confirmed',
            federated: true,
            origin_platform: origin_platform,
            metadata: { exchange_rate: rate, original_millitokens: data[:c3_millitokens].to_i },
            emitted_at: self.class.send(:safe_parse_time, data[:emitted_at]) || Time.current,
            confirmed_at: Time.current
          )
        end
      end

      def already_applied?(data)
        BetterTogether::C3::Token.exists?(
          source_system: token_source_system(data),
          source_ref: token_source_ref(data)
        )
      end

      def token_source_ref(data)
        data[:source_ref_hash].presence || data[:source_ref].presence || "token_seed:#{id}"
      end

      def token_source_system(data)
        data[:source_system].presence || 'federation'
      end

      # One-way SHA-256 hash of a source_ref bound to the originating platform.
      # Prevents internal agreement/settlement UUIDs from leaking to peer platforms
      # while still providing a unique, stable reference for audit correlation.
      def self.hash_source_ref(source_ref, platform_identifier)
        Digest::SHA256.hexdigest("c3token:#{source_ref}:#{platform_identifier}")
      end
      private_class_method :hash_source_ref

      def self.safe_parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        Time.current
      end
      private_class_method :safe_parse_time
    end
  end
end
