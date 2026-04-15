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
    #   201 { status: 'ok', seed_id: ..., applied: true }
    #   202 { status: 'pending', seed_id: ..., applied: false, reason: :symbol }
    #   409 { status: 'duplicate', message: ... }    — seed already applied
    #   403 { error: 'c3_exchange not enabled' }     — connection not opted in
    #   401                                          — bad / missing token
    class C3TokenSeedsController < ::BetterTogether::Federation::ApiController
      def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        return head :unauthorized unless connection

        unless connection.allows_c3_exchange?
          return render json: { error: 'c3_exchange not enabled on this connection' },
                        status: :forbidden
        end

        identifier = "c3_token:#{seed_params[:token_id]}"
        if BetterTogether::Seed.exists?(type: 'BetterTogether::C3::TokenSeed', identifier:)
          return render json: { status: 'duplicate', message: 'token seed already applied' }, status: :conflict
        end

        seed = BetterTogether::C3::TokenSeed.from_wire_params(seed_params, source_platform: connection.source_platform)
        seed.save!

        result = seed.apply_to_recipient_balance!(origin_platform: connection.source_platform)

        if result.applied
          render json: { status: 'ok', seed_id: seed.id, applied: true }, status: :created
        else
          render json: { status: 'pending', seed_id: seed.id, applied: false,
                         reason: result.reason }, status: :accepted
        end
      rescue ActiveRecord::RecordNotUnique
        # Lost a race with a concurrent identical request — seed already applied.
        render json: { status: 'duplicate', message: 'token seed already applied' }, status: :conflict
      rescue ActiveRecord::RecordInvalid, BetterTogether::C3::Balance::InsufficientBalance => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def connection
        @connection ||= begin
          token = access_token
          if token.present? && token.platform_connection.target_platform == Current.platform
            token.touch_last_used!
            token.platform_connection
          end
        end
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
