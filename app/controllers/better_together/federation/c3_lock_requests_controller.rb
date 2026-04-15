# frozen_string_literal: true

module BetterTogether
  module Federation
    # Receives C3 lock requests from peer CE platforms.
    # When Platform A accepts a cross-platform agreement where Bob (on Platform B)
    # is the payer, Platform A calls this endpoint on Platform B to lock Bob's C3.
    #
    # POST /federation/c3/lock_requests
    #   body: { c3_lock_request: { payer_did, c3_millitokens, agreement_ref } }
    #
    # Returns:
    #   200 { locked: true, lock_ref: <uuid>, locked_c3: <float> }
    #   402 { error: 'insufficient balance', available_c3: ... }
    #   404 { error: 'payer not found' }
    #   403 { error: 'c3_exchange not enabled' }
    class C3LockRequestsController < ::BetterTogether::Federation::ApiController
      def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        return head :unauthorized unless connection

        unless connection.allows_c3_exchange?
          return render json: { error: 'c3_exchange not enabled on this connection' },
                        status: :forbidden
        end

        payer = BetterTogether::Person.find_by(borgberry_did: lock_params[:payer_did])
        unless payer
          return render json: { error: "payer with DID '#{lock_params[:payer_did]}' not found on this platform" },
                        status: :not_found
        end

        millitokens = lock_params[:c3_millitokens].to_i
        c3_amount = millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE

        payer_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: payer, community: nil)
        payer_balance.lock!(c3_amount)

        render json: {
          locked: true,
          lock_ref: SecureRandom.uuid,
          locked_c3: c3_amount,
          payer_did: lock_params[:payer_did],
          agreement_ref: lock_params[:agreement_ref]
        }, status: :ok
      rescue BetterTogether::C3::Balance::InsufficientBalance => e
        payer_balance = BetterTogether::C3::Balance.find_by(holder: payer)
        render json: {
          error: e.message,
          available_c3: payer_balance&.available_c3 || 0.0
        }, status: :payment_required
      rescue ActiveRecord::RecordInvalid => e
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

      def lock_params
        params.require(:c3_lock_request).permit(:payer_did, :c3_millitokens, :agreement_ref)
      end
    end
  end
end
