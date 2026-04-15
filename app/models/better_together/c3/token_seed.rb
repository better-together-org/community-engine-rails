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
    class TokenSeed < BetterTogether::Seed
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
            :token_id, :earner_did, :payer_did, :contribution_type,
            :c3_millitokens, :source_ref, :source_system, :emitted_at
          ).to_h
        )
      end

      # Apply this seed's payload to the recipient's C3 balance.
      # If payer_did is present and the payer is found locally, settles from their
      # locked balance. Otherwise credits the recipient directly (simple inbound transfer).
      def apply_to_recipient_balance!(origin_platform: nil) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Naming/PredicateMethod
        data = payload_data.with_indifferent_access
        earner_did = data[:earner_did].to_s
        payer_did  = data[:payer_did].to_s
        millitokens = data[:c3_millitokens].to_i

        return false if earner_did.blank? || millitokens <= 0

        recipient = BetterTogether::Person.find_by(borgberry_did: earner_did)
        return false unless recipient

        # Federated balances are tracked per origin platform for cross-platform accounting.
        recipient_balance = BetterTogether::C3::Balance.find_or_create_by!(
          holder: recipient, community: nil, origin_platform: origin_platform
        )
        payer = payer_did.present? ? BetterTogether::Person.find_by(borgberry_did: payer_did) : nil

        transaction do
          if payer
            payer_balance = BetterTogether::C3::Balance.find_by!(holder: payer, community: nil)
            payer_balance.settle_to!(recipient_balance, millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE)
          else
            recipient_balance.credit!(millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE)
          end

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
            emitted_at: safe_parse_time(data[:emitted_at]) || Time.current,
            confirmed_at: Time.current
          )
        end

        true
      end

      private

      def self.safe_parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        Time.current
      end
      private_class_method :safe_parse_time
    end
  end
end
