# frozen_string_literal: true

module BetterTogether
  module Federation
    # Receives inbound C3::TokenSeed payloads from peer CE platforms.
    # Authenticated via FederationAccessToken with scope 'c3.exchange'.
    #
    # POST /federation/c3/token_seeds
    #   body: { c3_token_seed: { token_id, earner_did, payer_did (optional),
    #                            contribution_type, c3_millitokens,
    #                            source_ref, source_system, emitted_at } }
    #
    # Returns:
    #   200 { status: 'ok', seed_id: ..., applied: true } — replay of an existing seed
    #   201 { status: 'ok', seed_id: ..., applied: true } — first successful import
    #   202 { status: 'pending', seed_id: ..., applied: false, reason: :symbol }
    #   403 { error: 'c3_exchange not enabled' }          — connection not opted in
    #   401                                               — bad / missing token
    class C3TokenSeedsController < ::BetterTogether::Federation::ApiController
      def create # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        return head :unauthorized unless connection

        unless connection.allows_c3_exchange?
          return render json: { error: 'c3_exchange not enabled on this connection' },
                        status: :forbidden
        end

        identifier = "c3_token:#{seed_params[:token_id]}"
        seed = BetterTogether::C3::TokenSeed.find_by(
          type: 'BetterTogether::C3::TokenSeed',
          identifier: identifier
        )

        created = seed.nil?
        if created
          seed = BetterTogether::C3::TokenSeed.from_wire_params(
            seed_params,
            source_platform: connection.source_platform
          )
          begin
            seed.save!
          rescue ActiveRecord::RecordNotUnique
            seed = BetterTogether::C3::TokenSeed.find_by!(
              type: 'BetterTogether::C3::TokenSeed',
              identifier: identifier
            )
            created = false
          end
        end

        result = seed.apply_to_recipient_balance!(origin_platform: connection.source_platform)

        if result.applied
          render json: { status: 'ok', seed_id: seed.id, applied: true }, status: created ? :created : :ok
        else
          render json: { status: 'pending', seed_id: seed.id, applied: false,
                         reason: result.reason }, status: :accepted
        end
      rescue ActiveRecord::RecordInvalid, BetterTogether::C3::Balance::InsufficientBalance => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def connection
        @connection ||= connection_for_scope('c3.exchange')
      end

      def seed_params
        params.require(:c3_token_seed).permit(
          :token_id, :earner_did, :payer_did, :lock_ref,
          :contribution_type, :c3_millitokens,
          :source_ref, :source_ref_hash, :source_system, :emitted_at
        )
      end
    end
  end
end
